#!/usr/bin/env python3
"""
dazi-app API 契约同步检查。

解析 `functions/src/*.js` 中的 `exports.funcName = ...` 声明，
对比 `.plans/dazi-app/docs/api-contracts.md` 第 3 节 Cloud Functions 表格中
列出的函数名（反引号包裹），报告漂移。

- MISSING_IN_DOCS：代码里有但文档里没有 → 新函数未同步到文档
- STALE_IN_DOCS  ：文档里有但代码里没有 → 函数已删除但文档未更新

退出码 0 = 同步，1 = 有漂移。

用法：python scripts/check_api_contracts_sync.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
FUNCTIONS_DIR = PROJECT_ROOT / "functions" / "src"
DOCS_FILE = PROJECT_ROOT / ".plans" / "dazi-app" / "docs" / "api-contracts.md"

# 解析 `exports.funcName = ...` 声明
EXPORT_PATTERN = re.compile(r"^\s*exports\.(\w+)\s*=", re.MULTILINE)
# 解析 Markdown 表格行首（第一列）反引号包裹的函数名。
# 只匹配行首 `| \`funcName\` |` 模式，避免把入参/返回列里的反引号标识符误判为函数名。
DOC_FUNC_PATTERN = re.compile(r"^\|\s*`(\w+)`\s*\|", re.MULTILINE)


def collect_code_exports() -> dict[str, str]:
    """返回 {funcName: 相对路径}。跳过以下划线开头的内部函数。"""
    result: dict[str, str] = {}
    if not FUNCTIONS_DIR.exists():
        return result
    for f in FUNCTIONS_DIR.rglob("*.js"):
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for m in EXPORT_PATTERN.finditer(content):
            name = m.group(1)
            # 内部函数（约定以 _ 开头）不作为公开 API，不要求文档同步
            if name.startswith("_"):
                continue
            rel = f.relative_to(PROJECT_ROOT).as_posix()
            result[name] = rel
    return result


def collect_doc_functions() -> set[str]:
    """解析 api-contracts.md 第 3 节（Cloud Functions）中的函数名。"""
    if not DOCS_FILE.exists():
        return set()
    content = DOCS_FILE.read_text(encoding="utf-8", errors="ignore")
    # 只扫描 ## 3. Cloud Functions 到下一个 ## 之间
    section = re.search(
        r"^## 3\. Cloud Functions.*?(?=^## \d)",
        content,
        re.MULTILINE | re.DOTALL,
    )
    if not section:
        return set()
    block = section.group(0)
    # 排除以 _ 开头的内部函数
    return {m.group(1) for m in DOC_FUNC_PATTERN.finditer(block) if not m.group(1).startswith("_")}


def main() -> int:
    print("=" * 60)
    print("API Contracts Sync Check")
    print("=" * 60)

    code_funcs = collect_code_exports()
    doc_funcs = collect_doc_functions()

    if not code_funcs:
        print("[SKIP] functions/src/ 无 .js 文件或无 exports")
        return 0
    if not doc_funcs:
        print("[SKIP] api-contracts.md 未解析到第 3 节函数")
        return 0

    missing_in_docs = sorted(set(code_funcs.keys()) - doc_funcs)
    stale_in_docs = sorted(doc_funcs - set(code_funcs.keys()))

    if not missing_in_docs and not stale_in_docs:
        print(f"[OK] {len(code_funcs)} 个函数，文档与代码一致。")
        return 0

    if missing_in_docs:
        print("\n[FAIL] [CONTRACT-SYNC-MISSING] 文档缺失以下函数：")
        for name in missing_in_docs:
            print(f"  - `{name}`  (定义于 {code_funcs[name]})")
        print(
            "\n  FIX: 在 .plans/dazi-app/docs/api-contracts.md §3 对应文件子节添加表格行：\n"
            "    | `funcName` | callable/scheduled/trigger (region) | 入参 | 返回 | 行号 |"
        )

    if stale_in_docs:
        print("\n[FAIL] [CONTRACT-SYNC-STALE] 文档列出但代码中不存在的函数：")
        for name in stale_in_docs:
            print(f"  - `{name}`")
        print(
            "\n  FIX: 确认这些函数是否已删除/改名。若已删除，"
            "从 .plans/dazi-app/docs/api-contracts.md §3 移除对应表格行。"
        )

    print(
        f"\n汇总：{len(missing_in_docs)} MISSING_IN_DOCS, "
        f"{len(stale_in_docs)} STALE_IN_DOCS"
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
