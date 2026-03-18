#!/usr/bin/env python3
"""
诊断和验证 OpenClaw 配置健康状态。
用法:
  python3 check_health.py              # 完整诊断
  python3 check_health.py --doctor     # 只运行 doctor
  python3 check_health.py --nagios     # 机器可读输出 (Nagios 格式)
  python3 check_health.py --json       # JSON 格式输出
"""
import json
import subprocess
import sys
import argparse
import os
import socket

# 配置
CONFIG_PATH = "/home/node/.openclaw/openclaw.json"
DEFAULT_GATEWAY_URL = "http://127.0.0.1:18789/healthz"
DEFAULT_TIMEOUT = 30

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
    result = subprocess.run(
        ["sh", "-c", "docker compose version 2>/dev/null"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return "docker compose"
    result = subprocess.run(
        ["sh", "-c", "docker-compose --version 2>/dev/null"],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return "docker-compose"
    return "docker compose"

def run_doctor(project_dir, docker_cmd, timeout=60):
    """运行 openclaw doctor --fix"""
    cmd = f"cd {project_dir} && {docker_cmd} exec -T openclaw-gateway runuser -u node -- openclaw doctor --fix"
    try:
        result = subprocess.run(
            ["sh", "-c", cmd],
            capture_output=True, text=True, timeout=timeout
        )
        return result.stdout + result.stderr, None
    except subprocess.TimeoutExpired:
        return "", "doctor 执行超时"
    except Exception as e:
        return "", str(e)

def run_health_check(url=None, timeout=10):
    """检查 Gateway healthz"""
    url = url or DEFAULT_GATEWAY_URL
    try:
        result = subprocess.run(
            ["curl", "-sf", "--max-time", str(timeout), url],
            capture_output=True, text=True
        )
        return result.returncode == 0
    except Exception:
        return False

def check_sentinel(project_dir, docker_cmd):
    """检查 sentinel 文件是否存在"""
    cmd = f"cd {project_dir} && {docker_cmd} exec -T openclaw-gateway test -f /home/node/.openclaw_initialized"
    try:
        r = subprocess.run(
            ["sh", "-c", cmd],
            capture_output=True
        )
        return r.returncode == 0
    except Exception:
        return False

def check_json_valid():
    """检查配置文件 JSON 有效性"""
    try:
        with open(CONFIG_PATH, "r") as f:
            json.load(f)
        return True, None
    except FileNotFoundError:
        return False, "配置文件不存在"
    except json.JSONDecodeError as e:
        return False, str(e)
    except Exception as e:
        return False, str(e)

def check_container_running(project_dir, docker_cmd):
    """检查容器是否运行"""
    cmd = f"cd {project_dir} && {docker_cmd} ps --format '{{{{.Names}}}}' | grep -q openclaw-gateway"
    try:
        r = subprocess.run(
            ["sh", "-c", cmd],
            capture_output=True
        )
        return r.returncode == 0
    except Exception:
        return False

def main():
    parser = argparse.ArgumentParser(description="OpenClaw 配置健康检查")
    parser.add_argument("--doctor", action="store_true", help="只运行 doctor")
    parser.add_argument("--nagios", action="store_true", help="Nagios 格式输出")
    parser.add_argument("--json", action="store_true", help="JSON 格式输出")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help=f"超时时间 (秒，默认{DEFAULT_TIMEOUT})")
    parser.add_argument("--gateway-url", default=DEFAULT_GATEWAY_URL, help=f"Gateway healthz URL (默认：{DEFAULT_GATEWAY_URL})")
    args = parser.parse_args()

    # 初始化
    project_dir = find_project_dir()
    docker_cmd = get_docker_compose_cmd()

    # 检查容器是否运行
    container_running = check_container_running(project_dir, docker_cmd)
    if not container_running:
        if args.nagios:
            print("CRIT: OpenClaw 容器未运行")
            sys.exit(2)
        elif args.json:
            print(json.dumps({"status": "CRIT", "message": "OpenClaw 容器未运行"}))
            sys.exit(2)
        else:
            print("错误：OpenClaw 容器未运行")
            print(f"  请先启动容器：cd {project_dir} && {docker_cmd} up -d")
            sys.exit(2)

    # 执行检查
    json_ok, json_err = check_json_valid()
    sentinel = check_sentinel(project_dir, docker_cmd)
    health_ok = run_health_check(args.gateway_url, args.timeout)

    # 准备输出
    status = {
        "json_valid": json_ok,
        "json_error": json_err,
        "sentinel_exists": sentinel,
        "healthz_ok": health_ok,
        "container_running": True
    }

    if args.json:
        # JSON 输出
        if not json_ok:
            status["status"] = "CRIT"
            status["message"] = f"JSON 解析失败：{json_err}"
        elif not health_ok:
            status["status"] = "CRIT"
            status["message"] = "Gateway healthz 无响应"
        elif sentinel:
            status["status"] = "WARN"
            status["message"] = "sentinel 存在，entrypoint 修复已跳过"
        else:
            status["status"] = "OK"
            status["message"] = "配置有效，Gateway 健康"
        print(json.dumps(status, indent=2))
        sys.exit(0 if status["status"] == "OK" else (1 if status["status"] == "WARN" else 2))

    if args.nagios:
        # Nagios 输出
        if not json_ok:
            print(f"CRIT: JSON 解析失败 - {json_err}")
            sys.exit(2)
        if not health_ok:
            print("CRIT: Gateway healthz 无响应")
            sys.exit(2)
        if sentinel:
            print("WARN: sentinel 存在，entrypoint 修复已跳过")
            sys.exit(1)
        print("OK: 配置有效，Gateway 健康")
        sys.exit(0)

    # 人类可读输出
    if args.doctor:
        # 只运行 doctor
        print("=" * 50)
        print("OpenClaw 配置健康检查 (doctor 模式)")
        print("=" * 50)
        out, err = run_doctor(project_dir, docker_cmd, args.timeout)
        if err:
            print(f"错误：{err}")
            sys.exit(1)
        print(out)
        errors = "Errors: 0" in out
        print(f"\ndoctor 结论：{'✓ 无错误' if errors else '⚠ 有错误或警告'}")
        sys.exit(0 if errors else 1)

    # 完整诊断
    print("=" * 50)
    print("OpenClaw 配置健康检查")
    print("=" * 50)
    print(f"  容器状态：{'✓ 运行中' if container_running else '✗ 未运行'}")
    print(f"  JSON 格式：  {'✓ 有效' if json_ok else '✗ 无效 - ' + json_err}")
    print(f"  sentinel:   {'存在 (修复已跳过)' if sentinel else '不存在'}")
    print(f"  healthz:    {'✓ 正常' if health_ok else '✗ 无响应'}")

    # 综合判断
    overall_ok = container_running and json_ok and health_ok
    if not overall_ok:
        print("\n状态：✗ 异常")
        if not json_ok:
            print("建议：运行 python3 fix_json.py 修复配置文件")
        if not health_ok:
            print("建议：检查容器日志 docker compose logs openclaw-gateway")
        sys.exit(1)

    if sentinel:
        print("\n状态：⚠ 警告 (sentinel 存在)")
        print("建议：如需重新执行自动修复，运行:")
        print(f"  cd {project_dir} && {docker_cmd} exec -T openclaw-gateway rm -f /home/node/.openclaw_initialized")
        sys.exit(1)

    print("\n状态：✓ 健康")
    sys.exit(0)

if __name__ == "__main__":
    main()
