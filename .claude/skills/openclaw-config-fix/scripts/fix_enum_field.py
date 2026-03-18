#!/usr/bin/env python3
"""
修复枚举字段非法值。
从日志中解析 "field.path: invalid config: must be equal to one of the allowed values (allowed: X, Y, Z)"
然后将字段值改为允许值中的第一个。

用法:
  python3 fix_enum_field.py
  # 自动从 docker compose logs 提取错误并修复

  python3 fix_enum_field.py --dry-run
  # 只打印当前值和期望值，不写入

  python3 fix_enum_field.py --field plugins.entries.acpx.config.permissionMode --allowed approve-all approve-reads deny-all
  # 手动指定字段路径和允许值
"""
import json
import sys
import argparse
import subprocess
import re
import os
from pathlib import Path

# 配置：容器内配置路径
CONFIG_PATH = "/home/node/.openclaw/openclaw.json"

def find_project_dir():
    """
    查找项目目录。按优先级：
    1. 当前目录有 docker-compose.yml
    2. ~/openclaw
    3. ~/openclaw-devkit
    4. 环境变量 OPENCLAW_PROJECT_DIR
    """
    # 检查环境变量
    if os.environ.get("OPENCLAW_PROJECT_DIR"):
        return os.environ["OPENCLAW_PROJECT_DIR"]

    # 检查当前目录
    cwd = os.getcwd()
    if os.path.exists(os.path.join(cwd, "docker-compose.yml")):
        return cwd

    # 检查 ~/openclaw
    home = os.path.expanduser("~")
    candidate = os.path.join(home, "openclaw")
    if os.path.exists(os.path.join(candidate, "docker-compose.yml")):
        return candidate

    # 检查 ~/openclaw-devkit
    candidate = os.path.join(home, "openclaw-devkit")
    if os.path.exists(os.path.join(candidate, "docker-compose.yml")):
        return candidate

    # 默认返回当前目录
    return cwd

def get_docker_compose_cmd():
    """检测 docker compose 命令格式"""
    # 优先尝试 docker compose (v2)
    result = subprocess.run(
        ["sh", "-c", "docker compose version 2>/dev/null"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return "docker compose"

    # 回退到 docker-compose (v1)
    result = subprocess.run(
        ["sh", "-c", "docker-compose --version 2>/dev/null"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return "docker-compose"

    # 默认
    return "docker compose"

def get_log_error(project_dir, docker_cmd):
    """从 docker compose logs 中提取枚举错误"""
    cmd = f"cd {project_dir} && {docker_cmd} logs --tail 200 openclaw-gateway 2>&1"
    result = subprocess.run(
        ["sh", "-c", cmd],
        capture_output=True, text=True, timeout=30
    )
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if "invalid config" in line.lower() and "allowed values" in line.lower():
            return line
    return None

def parse_error(line):
    """解析错误行，提取字段路径和允许值列表"""
    # 匹配: plugins.entries.acpx.config.permissionMode: invalid config: ...
    # 匹配：- plugins.entries.xxx: invalid config: ...
    path_match = re.search(r'[-\s]?(\S+): invalid config', line)
    # 匹配：(allowed: "X", "Y", "Z")
    allowed_match = re.search(r'allowed:\s*"([^"]+)"(?:\s*,\s*"([^"]+)")*', line)
    if not allowed_match:
        allowed_match = re.search(r'allowed:\s*([^)]+)', line)

    path = path_match.group(1) if path_match else None

    if allowed_match:
        allowed_str = allowed_match.group(0).replace("allowed:", "").strip()
        # 提取所有引号中的值
        allowed_vals = re.findall(r'"([^"]+)"', allowed_str)
        if not allowed_vals:
            allowed_vals = [v.strip() for v in allowed_str.strip("() ").split(",")]
    else:
        allowed_vals = []

    return path, allowed_vals

def get_by_path(cfg, path):
    """返回 (value, parent_obj, key)"""
    keys = path.split(".")
    parent = None
    for i, key in enumerate(keys):
        parent = cfg
        if isinstance(cfg, dict) and key in cfg:
            cfg = cfg[key]
        else:
            return None, None, None
    return cfg, parent, keys[-1]

def main():
    parser = argparse.ArgumentParser(description="修复 OpenClaw 配置枚举字段非法值")
    parser.add_argument("--field", help="字段路径 (dot notation)")
    parser.add_argument("--allowed", nargs="+", help="允许的值列表")
    parser.add_argument("--dry-run", action="store_true", help="只打印，不写入")
    parser.add_argument("--verbose", "-v", action="store_true", help="详细输出")
    args = parser.parse_args()

    # 初始化
    project_dir = find_project_dir()
    docker_cmd = get_docker_compose_cmd()

    if args.verbose:
        print(f"[INFO] 项目目录：{project_dir}")
        print(f"[INFO] Docker 命令：{docker_cmd}")

    field_path = args.field
    allowed_vals = args.allowed

    if not field_path or not allowed_vals:
        # 从日志自动提取
        try:
            line = get_log_error(project_dir, docker_cmd)
        except subprocess.TimeoutExpired:
            print("[ERROR] 读取日志超时")
            sys.exit(1)
        except Exception as e:
            print(f"[ERROR] 读取日志失败：{e}")
            sys.exit(1)

        if not line:
            print("[ERROR] 无法从日志中找到枚举错误，请手动指定 --field 和 --allowed")
            print("  用法：python3 fix_enum_field.py --field <path> --allowed <val1> <val2>")
            sys.exit(1)
        print(f"[日志] {line.strip()}")
        p, a = parse_error(line)
        if p:
            field_path = p
            print(f"  → 解析到字段：{field_path}")
        if a:
            allowed_vals = a
            print(f"  → 解析到允许值：{allowed_vals}")
        if not field_path or not allowed_vals:
            print("[ERROR] 无法解析日志，请手动指定 --field 和 --allowed")
            sys.exit(1)

    # 读取配置
    try:
        with open(CONFIG_PATH, "r") as f:
            cfg = json.load(f)
    except FileNotFoundError:
        print(f"[ERROR] 配置文件不存在：{CONFIG_PATH}")
        print("  请确认容器已启动且配置已挂载")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"[ERROR] 配置文件 JSON 无效：{e}")
        sys.exit(1)

    current, parent, key = get_by_path(cfg, field_path)

    if current is None:
        print(f"[ERROR] 字段路径不存在：{field_path}")
        print("  可用字段路径示例:")
        print("    plugins.entries.acpx.config.permissionMode")
        print("    gateway.bind")
        sys.exit(1)

    print(f"字段：{field_path}")
    print(f"当前值：{repr(current)}")
    print(f"允许值：{allowed_vals}")

    if current in allowed_vals:
        print("值已合法，无需修复")
        sys.exit(0)

    if args.dry_run:
        print(f"[DRY RUN] 会将 {repr(current)} -> {allowed_vals[0]}")
        sys.exit(0)

    # 备份原配置
    backup_path = CONFIG_PATH + ".bak"
    try:
        with open(backup_path, "w") as f:
            json.dump(cfg, f, indent=2)
        if args.verbose:
            print(f"[INFO] 已备份配置到 {backup_path}")
    except Exception as e:
        print(f"[WARN] 备份失败：{e}，继续修复...")

    # 修复
    try:
        parent[key] = allowed_vals[0]
        with open(CONFIG_PATH, "w") as f:
            json.dump(cfg, f, indent=2)
        print(f"[FIXED] {field_path}: {repr(current)} -> {repr(allowed_vals[0])}")
    except Exception as e:
        print(f"[ERROR] 写入配置失败：{e}")
        # 尝试恢复备份
        try:
            import shutil
            shutil.copy(backup_path, CONFIG_PATH)
            print("[INFO] 已恢复备份")
        except:
            pass
        sys.exit(1)

if __name__ == "__main__":
    main()
