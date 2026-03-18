#!/usr/bin/env python3
"""
修复 OpenClaw 配置文件的常见 JSON 格式问题。
用法:
  python3 fix_json.py          # 诊断并修复
  python3 fix_json.py --check  # 只检查，不修复
  python3 fix_json.py --fix    # 强制修复
  python3 fix_json.py --verbose  # 详细输出
"""
import json
import re
import sys
import argparse
import os
import shutil
from datetime import datetime

# 配置
CONFIG_PATH = "/home/node/.openclaw/openclaw.json"

# 常见 JSON 修复规则（按优先级排序）
COMMON_FIXES = [
    # 1. 尾部逗号：{ "a": 1, } -> { "a": 1 }
    (r',\s*([\]}])', r'\1', 0),
    # 2. 单行注释：// comment
    (r'//.*$', '', re.MULTILINE),
    # 3. 多行注释：/* ... */
    (r'/\*.*?\*/', '', re.DOTALL),
    # 4.  trailing comma in arrays: [1, 2, ] -> [1, 2]
    (r',\s*]', ']', 0),
    # 5. 不规范的空格：{  "key"  :  "value"  } -> {"key": "value"}
    (r'{\s+', '{', 0),
    (r'\s+}', '}', 0),
]

def try_parse(text):
    """尝试解析 JSON，失败返回 None"""
    try:
        return json.loads(text), None
    except json.JSONDecodeError as e:
        return None, str(e)

def apply_fixes(text, max_iterations=5):
    """
    迭代应用修复规则，直到 JSON 有效或达到最大迭代次数。
    返回 (修复后的文本，修改历史，错误信息)
    """
    current = text
    history = []

    for iteration in range(max_iterations):
        # 尝试解析
        cfg, err = try_parse(current)
        if cfg is not None:
            # JSON 有效，返回
            return current, history, None

        # 应用所有规则
        fixed = current
        iteration_changes = []
        for i, rule in enumerate(COMMON_FIXES):
            if len(rule) == 2:
                pattern, replacement = rule
                flags = 0
            else:
                pattern, replacement, flags = rule
            new_fixed = re.sub(pattern, replacement, fixed, flags=flags)
            if new_fixed != fixed:
                iteration_changes.append(f"规则 {i+1}: {pattern[:30]}...")
                fixed = new_fixed

        # 如果没有变化，跳出循环
        if fixed == current:
            break

        current = fixed
        history.append({
            "iteration": iteration + 1,
            "changes": iteration_changes,
            "error": err
        })

    # 最终尝试解析
    cfg, err = try_parse(current)
    if cfg is not None:
        return current, history, None
    return current, history, err

def create_backup(path):
    """创建备份文件，返回备份路径"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = f"{path}.bak.{timestamp}"
    try:
        shutil.copy2(path, backup)
        return backup
    except Exception as e:
        return None

def main():
    parser = argparse.ArgumentParser(description="修复 OpenClaw 配置文件 JSON 格式问题")
    parser.add_argument("--check", action="store_true", help="只检查，不修复")
    parser.add_argument("--fix", action="store_true", help="强制修复（忽略 dry-run）")
    parser.add_argument("--verbose", "-v", action="store_true", help="详细输出")
    parser.add_argument("--max-iterations", type=int, default=5, help="最大修复迭代次数 (默认：5)")
    args = parser.parse_args()

    # 读取配置
    try:
        with open(CONFIG_PATH, "r") as f:
            raw = f.read()
    except FileNotFoundError:
        print(f"[ERROR] 配置文件不存在：{CONFIG_PATH}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] 读取配置失败：{e}")
        sys.exit(1)

    # 尝试解析
    cfg, err = try_parse(raw)
    if cfg is not None:
        print("[OK] JSON 格式有效")
        if args.verbose:
            print(f"  文件大小：{len(raw)} 字节")
            print(f"  顶层键：{', '.join(cfg.keys())}")
        return

    print(f"[WARN] JSON 解析失败：{err}")
    print("尝试自动修复...")

    # 应用修复
    fixed, history, final_err = apply_fixes(raw, args.max_iterations)

    if not history:
        print("[ERROR] 无法自动修复，请手动检查文件")
        print("  常见问题:")
        print("    - 尾部逗号：{ \"a\": 1, }")
        print("    - 注释：// comment 或 /* ... */")
        print("    - 字符串未闭合：\"value")
        sys.exit(1)

    # 输出修复历史
    print(f"应用了 {len(history)} 轮修复:")
    for h in history:
        print(f"  迭代 {h['iteration']}:")
        for c in h["changes"]:
            print(f"    - {c}")
        if args.verbose:
            print(f"    错误：{h['error']}")

    if args.check:
        print("[INFO] --check 模式，未写入")
        sys.exit(0)

    # 验证修复后能解析
    cfg, err = try_parse(fixed)
    if cfg is None:
        print(f"[ERROR] 自动修复后仍无法解析：{err}")
        print("  建议：手动检查文件内容")
        sys.exit(1)

    # 创建备份
    backup = create_backup(CONFIG_PATH)
    if backup:
        print(f"[INFO] 已备份原始文件：{backup}")
    else:
        print("[WARN] 备份失败，继续写入...")

    # 写入修复后的配置
    try:
        with open(CONFIG_PATH, "w") as f:
            json.dump(cfg, f, indent=2)
        print(f"[FIXED] 已写入修复")
    except Exception as e:
        print(f"[ERROR] 写入配置失败：{e}")
        # 尝试恢复备份
        if backup:
            try:
                shutil.copy(backup, CONFIG_PATH)
                print("[INFO] 已恢复备份")
            except:
                pass
        sys.exit(1)

if __name__ == "__main__":
    main()
