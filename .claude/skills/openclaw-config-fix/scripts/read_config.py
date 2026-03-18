#!/usr/bin/env python3
"""
读取并分析 OpenClaw 配置。
用法：
  python3 read_config.py                    # 打印完整配置
  python3 read_config.py --field <path>     # 打印指定字段
  python3 read_config.py --tree             # 打印树形结构
  python3 read_config.py --keys             # 只打印顶层键

示例:
  python3 read_config.py
  python3 read_config.py --field plugins.entries.acpx.config.permissionMode
  python3 read_config.py --tree --max-depth 2
"""
import json
import sys
import argparse

# 配置路径（容器内）
CONFIG_PATH = "/home/node/.openclaw/openclaw.json"

def load_config(path=None):
    """加载配置文件"""
    cfg_path = path or CONFIG_PATH
    try:
        with open(cfg_path, "r") as f:
            return json.load(f), None
    except FileNotFoundError:
        return None, f"配置文件不存在：{cfg_path}"
    except json.JSONDecodeError as e:
        return None, f"JSON 解析失败：{e}"
    except PermissionError:
        return None, f"无权限读取：{cfg_path}"
    except Exception as e:
        return None, f"读取失败：{e}"

def get_by_path(cfg, path):
    """
    按 dot notation 路径获取嵌套值。
    返回 (value, error)
    """
    if not path:
        return cfg, None
    keys = path.split(".")
    current = cfg
    for i, key in enumerate(keys):
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            # 构建友好错误信息
            full_path = ".".join(keys[:i+1])
            available = list(current.keys()) if isinstance(current, dict) else []
            return None, f"路径 '{full_path}' 不存在 (可用键：{', '.join(available[:5])}{'...' if len(available) > 5 else ''})"
    return current, None

def print_tree(cfg, prefix="", max_depth=3, depth=0):
    """打印配置树形结构"""
    if depth >= max_depth:
        print(f"{prefix}...")
        return
    if isinstance(cfg, dict):
        for i, (k, v) in enumerate(cfg.items()):
            last = i == len(cfg) - 1
            bracket = "└── " if last else "├── "
            if isinstance(v, dict):
                print(f"{prefix}{bracket}{k}:")
                ext = "    " if last else "│   "
                print_tree(v, prefix + ext, max_depth, depth + 1)
            elif isinstance(v, list):
                print(f"{prefix}{bracket}{k}: <list {len(v)}>")
            else:
                val_str = repr(v)
                if len(val_str) > 50:
                    val_str = val_str[:47] + "..."
                print(f"{prefix}{bracket}{k}: {val_str}")
    elif isinstance(cfg, list):
        print(f"{prefix}<list {len(cfg)}>")
    else:
        print(f"{prefix}{repr(cfg)}")

def main():
    parser = argparse.ArgumentParser(
        description="读取并分析 OpenClaw 配置",
        formatter_class=argparse.RawDescriptionHelpText,
        epilog="""
示例:
  %(prog)s                              # 完整配置
  %(prog)s --field plugins.entries.acpx # 指定字段
  %(prog)s --tree --max-depth 2         # 树形结构
  %(prog)s --keys                       # 顶层键列表
        """
    )
    parser.add_argument("--field", help="字段路径 (dot notation)，如 plugins.entries.acpx.config")
    parser.add_argument("--tree", action="store_true", help="打印配置树形结构")
    parser.add_argument("--keys", action="store_true", help="只打印顶层键列表")
    parser.add_argument("--max-depth", type=int, default=3, help="树形结构最大深度 (默认：3)")
    parser.add_argument("--config-path", help=f"配置文件路径 (默认：{CONFIG_PATH})")
    parser.add_argument("--verbose", "-v", action="store_true", help="详细输出")
    args = parser.parse_args()

    # 加载配置
    cfg_path = args.config_path or CONFIG_PATH
    cfg, err = load_config(cfg_path)
    if err:
        print(f"[ERROR] {err}")
        sys.exit(1)

    if args.verbose:
        print(f"[INFO] 已加载配置：{cfg_path}", file=sys.stderr)

    # 输出模式
    if args.keys:
        # 只打印顶层键
        for k in cfg.keys():
            print(k)
    elif args.field:
        # 指定字段
        val, err = get_by_path(cfg, args.field)
        if err:
            print(f"[ERROR] {err}")
            sys.exit(1)
        # 智能输出：字典/列表用 JSON，标量直接打印
        if isinstance(val, (dict, list)):
            print(json.dumps(val, indent=2))
        else:
            print(val)
    elif args.tree:
        # 树形结构
        print_tree(cfg, max_depth=args.max_depth)
    else:
        # 完整配置
        print(json.dumps(cfg, indent=2))

if __name__ == "__main__":
    main()
