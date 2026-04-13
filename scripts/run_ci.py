#!/usr/bin/env python3
"""
dazi-app CI 入口脚本。
运行黄金原则检查 + 项目特定检查。
退出码 0 = 全部通过，1 = 有失败。

用法：python scripts/run_ci.py
"""

import sys
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent


def run_api_contracts_sync() -> bool:
    """运行 API 契约同步检查（文档/代码漂移）。"""
    print("=" * 60)
    print("[0/4] 运行 API 契约同步检查 (check_api_contracts_sync.py)")
    print("=" * 60)
    script = Path(__file__).parent / "check_api_contracts_sync.py"
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=PROJECT_ROOT,
        capture_output=False,
    )
    return result.returncode == 0


def run_golden_rules() -> bool:
    """运行通用黄金原则检查。"""
    print("=" * 60)
    print("[1/4] 运行黄金原则 (golden_rules.py)")
    print("=" * 60)
    script = Path(__file__).parent / "golden_rules.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "client/lib",
            "functions/src",
            "--docs",
            ".plans/dazi-app/docs",
        ],
        cwd=PROJECT_ROOT,
        capture_output=False,
    )
    return result.returncode == 0


def run_flutter_tests() -> bool:
    """运行 Flutter 客户端测试。"""
    print("=" * 60)
    print("[2/4] 运行 Flutter 测试")
    print("=" * 60)
    client_dir = PROJECT_ROOT / "client"
    if not client_dir.exists():
        print("[SKIP] client/ 不存在")
        return True
    test_dir = client_dir / "test"
    if not test_dir.exists() or not any(test_dir.iterdir()):
        print("[SKIP] client/test/ 为空，暂无测试")
        return True
    result = subprocess.run(
        ["flutter", "test"],
        cwd=client_dir,
        capture_output=False,
        shell=True,  # Windows: flutter 是 .bat,需要 shell
    )
    return result.returncode == 0


def run_functions_tests() -> bool:
    """运行 Firebase Functions 测试。"""
    print("=" * 60)
    print("[3/4] 运行 Functions 测试")
    print("=" * 60)
    functions_dir = PROJECT_ROOT / "functions"
    if not functions_dir.exists():
        print("[SKIP] functions/ 不存在")
        return True
    pkg_json = functions_dir / "package.json"
    if not pkg_json.exists():
        print("[SKIP] functions/package.json 不存在")
        return True
    # 如果 package.json 里没有 test 脚本，跳过
    import json
    with open(pkg_json, encoding="utf-8") as f:
        pkg = json.load(f)
    if "test" not in pkg.get("scripts", {}):
        print("[SKIP] functions/package.json 无 test 脚本")
        return True
    result = subprocess.run(
        ["npm", "test"],
        cwd=functions_dir,
        capture_output=False,
        shell=True,
    )
    return result.returncode == 0


def main() -> int:
    print("\n>>> dazi-app CI 开始 <<<\n")
    results = {
        "api_contracts_sync": run_api_contracts_sync(),
        "golden_rules": run_golden_rules(),
        "flutter_tests": run_flutter_tests(),
        "functions_tests": run_functions_tests(),
    }
    print("\n" + "=" * 60)
    print("CI 汇总")
    print("=" * 60)
    for name, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  {status}  {name}")

    all_pass = all(results.values())
    if all_pass:
        print("\n>>> CI 全部通过 <<<\n")
        return 0
    else:
        print("\n>>> CI 失败——修复后再提交 reviewer <<<\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
