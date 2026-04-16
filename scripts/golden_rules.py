#!/usr/bin/env python3
"""
Golden Rules -- universal code health checks for CCteam-creator projects.

Pre-installed by CCteam-creator skill. Copied to <project>/scripts/ during
Step 3.6 (Harness Setup). Called by run_ci.py as part of the CI pipeline.

Usage:
    # Standalone
    python golden_rules.py src/backend src/frontend

    # From run_ci.py
    from golden_rules import check_all
    result = check_all(["src/backend", "src/frontend"], docs_dir=".plans/<project>/docs")

Error messages follow agent-readable format:
    [TAG] <what's wrong>
      File: <path:line>
      FIX: <exactly how to fix it>
"""
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Result collector (no global mutable state)
# ---------------------------------------------------------------------------


@dataclass
class CheckResult:
    fails: int = 0
    warns: int = 0
    infos: int = 0

    def fail(self, tag, msg, fix):
        self.fails += 1
        print(f"  [FAIL] [{tag}] {msg}")
        print(f"    FIX: {fix}\n")

    def warn(self, tag, msg, fix):
        self.warns += 1
        print(f"  [WARN] [{tag}] {msg}")
        print(f"    FIX: {fix}\n")

    def info(self, tag, msg, fix):
        self.infos += 1
        print(f"  [INFO] [{tag}] {msg}")
        print(f"    FIX: {fix}\n")


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------
CODE_EXTENSIONS = {
    ".py", ".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte",
    ".go", ".rs", ".java", ".kt", ".rb", ".php",
    ".dart",  # Flutter 客户端
}

EXCLUDE_DIRS = {
    "node_modules", ".git", "__pycache__", ".venv", "venv",
    "dist", "build", ".next", ".nuxt", "coverage", ".plans",
}


def _iter_code_files(src_dirs):
    """Yield Path objects for code files in src_dirs, skipping excluded dirs and minified files."""
    for src_dir in src_dirs:
        root = Path(src_dir)
        if not root.exists():
            continue
        for f in root.rglob("*"):
            if not f.is_file():
                continue
            if f.suffix not in CODE_EXTENSIONS:
                continue
            if any(part in EXCLUDE_DIRS for part in f.parts):
                continue
            # Skip minified files (e.g., foo.min.js)
            if ".min." in f.name:
                continue
            yield f


# ---------------------------------------------------------------------------
# GR-1: File Size
# ---------------------------------------------------------------------------
def check_file_size(src_dirs, result, warn_limit=800, fail_limit=1200):
    """Files over warn_limit lines get WARN; over fail_limit get FAIL."""
    print("[GR-1] File Size Check")
    found = False
    for f in _iter_code_files(src_dirs):
        try:
            lines = len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
        except Exception:
            continue
        if lines > fail_limit:
            result.fail("GR-FILE-SIZE", f"{f} -- {lines} lines (limit: {fail_limit})",
                        "Split into smaller modules. Extract helper functions or classes.")
            found = True
        elif lines > warn_limit:
            result.warn("GR-FILE-SIZE", f"{f} -- {lines} lines (limit: {warn_limit})",
                        "Consider splitting. Files over 800 lines are hard for agents to navigate.")
            found = True
    if not found:
        print("  [OK] All files within size limits.\n")


# ---------------------------------------------------------------------------
# GR-2: Hardcoded Secrets
# ---------------------------------------------------------------------------
SECRET_PATTERNS = [
    (r"""['"]sk-[a-zA-Z0-9]{20,}['"]""", "Possible OpenAI/Stripe API key"),
    (r"""['"]ghp_[a-zA-Z0-9]{30,}['"]""", "Possible GitHub personal access token"),
    (r"""['"]AKIA[A-Z0-9]{16}['"]""", "Possible AWS access key"),
    (r"""(?i)(password|secret|api_key|apikey|token)\s*[:=]\s*['"][^'"]{8,}['"]""",
     "Possible hardcoded secret"),
]

# Lines containing these markers are likely examples/placeholders, not real secrets
EXAMPLE_MARKERS = ("example", "placeholder", "your_key_here", "xxx", "changeme", "<your")

# 文件白名单：这些文件中的 "apiKey" 等字段不是真密钥。
# - firebase_options.dart：由 `flutterfire configure` 生成，apiKey 是客户端标识符，
#   不是访问控制密钥（Firebase 客户端 key 不控制后端访问，这由 Firestore/Storage Rules
#   保证）。所有 Firebase 客户端 SDK 都必须把这些值嵌在前端代码里。
# 参考：https://firebase.google.com/docs/projects/api-keys
SECRET_FILE_ALLOWLIST = {"firebase_options.dart"}


def check_secrets(src_dirs, result):
    """Scan for hardcoded secrets using regex patterns."""
    print("[GR-2] Hardcoded Secrets Check")
    found = False
    for f in _iter_code_files(src_dirs):
        if f.name in SECRET_FILE_ALLOWLIST:
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for i, line in enumerate(content.splitlines(), 1):
            stripped = line.strip()
            # Skip lines that are clearly examples/placeholders
            if any(marker in stripped.lower() for marker in EXAMPLE_MARKERS):
                continue
            for pattern, desc in SECRET_PATTERNS:
                if re.search(pattern, line):
                    result.fail("GR-SECRET", f"{f}:{i} -- {desc}",
                                "Move to environment variable. Never commit secrets to code.")
                    found = True
                    break  # one match per line is enough
    if not found:
        print("  [OK] No hardcoded secrets detected.\n")


# ---------------------------------------------------------------------------
# GR-3: No console.log in Production Code
# ---------------------------------------------------------------------------
CONSOLE_PATTERN = re.compile(r"\bconsole\.(log|debug|info|warn|error)\b")
TEST_DIR_NAMES = {"test", "tests", "__tests__", "spec", "scripts", "e2e", "cypress"}
# 服务端目录——这些目录里的 console.log 等同于 structured logger(Cloud Logging 等)
SERVER_DIR_NAMES = {"functions"}


def check_console_log(src_dirs, result):
    """Detect console.log in production code (not test files or server code)."""
    print("[GR-3] Console Log Check")
    found = False
    for f in _iter_code_files(src_dirs):
        if f.suffix not in {".ts", ".tsx", ".js", ".jsx", ".vue", ".svelte"}:
            continue
        if any(part in TEST_DIR_NAMES for part in f.parts):
            continue
        # Firebase Functions / 服务端代码中 console.log 是合法 logging
        if any(part in SERVER_DIR_NAMES for part in f.parts):
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for i, line in enumerate(content.splitlines(), 1):
            if CONSOLE_PATTERN.search(line):
                stripped = line.strip()
                if stripped.startswith("//"):
                    continue
                result.warn("GR-CONSOLE", f"{f}:{i} -- {stripped[:80]}",
                            "Remove console.log from production code. Use a structured logger instead.")
                found = True
    if not found:
        print("  [OK] No console.log in production code.\n")


# ---------------------------------------------------------------------------
# GR-4: Doc Freshness (requires git)
# ---------------------------------------------------------------------------
def check_doc_freshness(docs_dir, src_dirs, result, stale_commit_threshold=10):
    """Compare docs/ last-modified commit vs source code commits.

    If source has N+ commits since docs were last touched, emit WARN.
    Requires git. Silently skips if git is not available or docs_dir missing.
    """
    print("[GR-4] Doc Freshness Check")
    docs_path = Path(docs_dir)
    if not docs_path.exists():
        print("  [SKIP] docs/ directory not found. Skipping freshness check.\n")
        return

    doc_files = {
        "api-contracts.md": "API contract",
        "architecture.md": "architecture",
        "invariants.md": "invariants",
    }

    found = False
    for doc_name, label in doc_files.items():
        doc_file = docs_path / doc_name
        if not doc_file.exists():
            continue
        try:
            last_doc_commit = subprocess.run(
                ["git", "log", "-1", "--format=%H", "--", str(doc_file)],
                capture_output=True, text=True, timeout=10
            ).stdout.strip()

            if not last_doc_commit:
                continue

            src_commits = 0
            for src_dir in src_dirs:
                if not Path(src_dir).exists():
                    continue
                count_result = subprocess.run(
                    ["git", "rev-list", "--count", f"{last_doc_commit}..HEAD", "--", src_dir],
                    capture_output=True, text=True, timeout=10
                )
                count = count_result.stdout.strip()
                if count.isdigit():
                    src_commits += int(count)

            if src_commits >= stale_commit_threshold:
                quoted_dirs = " ".join(f'"{d}"' for d in src_dirs)
                result.warn(
                    "GR-DOC-STALE",
                    f"{doc_file} -- {src_commits} source commits since last doc update",
                    f"Review and update {label} docs. Run: git log --oneline {last_doc_commit}..HEAD -- {quoted_dirs}")
                found = True
        except Exception:
            continue

    if not found:
        print("  [OK] All docs appear fresh.\n")


# ---------------------------------------------------------------------------
# GR-5: Invariant Coverage
# ---------------------------------------------------------------------------
def check_invariant_coverage(docs_dir, result):
    """Scan invariants.md for items marked 'no test' and report them."""
    print("[GR-5] Invariant Coverage Check")
    inv_file = Path(docs_dir) / "invariants.md"
    if not inv_file.exists():
        print("  [SKIP] docs/invariants.md not found. Skipping.\n")
        return

    try:
        content = inv_file.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        print("  [SKIP] Could not read invariants.md.\n")
        return

    no_test_count = 0
    for i, line in enumerate(content.splitlines(), 1):
        if re.search(r"(?i)status:\s*no\s*test", line):
            result.info(
                "GR-INV-NO-TEST",
                f"docs/invariants.md:{i} -- Invariant without automated test: {line.strip()[:80]}",
                "Write an automated test for this invariant. Untested invariants rely on human memory.")
            no_test_count += 1

    if no_test_count == 0:
        print("  [OK] All invariants have test coverage (or no invariants defined).\n")
    else:
        print(f"  {no_test_count} invariant(s) without automated tests.\n")


# ---------------------------------------------------------------------------
# GR-6: Hardcoded Colors in Flutter widgets (INV-7)
# ---------------------------------------------------------------------------
# 匹配 Color(0xFF...) 字面量，但允许：
#   - 定义在 AppColors / app_colors.dart 中（那是颜色源头）
#   - 注释行
COLOR_LITERAL_PATTERN = re.compile(r"Color\(\s*0x[0-9A-Fa-f]{6,8}\s*\)")
# 允许在这些文件中硬编码——它们是颜色源头
COLOR_SOURCE_FILES = {"app_colors.dart", "colors.dart", "theme.dart", "dazi_colors.dart"}


def check_hardcoded_colors(src_dirs, result):
    """Scan Flutter widgets for Color(0xFF...) literals. INV-7 enforcement."""
    print("[GR-6] Hardcoded Colors Check (INV-7)")
    found = False
    for f in _iter_code_files(src_dirs):
        if f.suffix != ".dart":
            continue
        # 跳过颜色定义源头
        if f.name in COLOR_SOURCE_FILES:
            continue
        # 跳过测试文件
        if any(part in TEST_DIR_NAMES for part in f.parts):
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for i, line in enumerate(content.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if COLOR_LITERAL_PATTERN.search(line):
                result.warn(
                    "GR-COLOR-HARDCODE",
                    f"{f}:{i} -- {stripped[:80]}",
                    "Move to AppColors in core/theme/app_colors.dart. "
                    "Widgets must reference tokens, not Color(0xFF...) literals.")
                found = True
    if not found:
        print("  [OK] No hardcoded Color literals in widgets.\n")


# ---------------------------------------------------------------------------
# GR-7: Algolia Credentials Hardcoded (INV-9)
# ---------------------------------------------------------------------------
# Algolia App ID:  10 位大写字母数字（如 B1G2H3I4J5）
# Algolia API Key: 32 位十六进制小写
ALGOLIA_APP_ID_PATTERN = re.compile(r"""['"]([A-Z0-9]{10})['"]""")
ALGOLIA_KEY_PATTERN = re.compile(r"""['"]([a-f0-9]{32})['"]""")
ALGOLIA_CONTEXT_KEYWORDS = ("algolia", "appid", "app_id", "searchkey", "search_key")


def check_algolia_secrets(src_dirs, result):
    """Detect likely Algolia App ID / Search Key literals. INV-9 enforcement."""
    print("[GR-7] Algolia Credentials Check (INV-9)")
    found = False
    for f in _iter_code_files(src_dirs):
        if f.suffix != ".dart":
            continue
        if any(part in TEST_DIR_NAMES for part in f.parts):
            continue
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        lines = content.splitlines()
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            # 只在 Algolia 上下文附近扫描（避免误报所有 32 位 hex）
            ctx_window = " ".join(lines[max(0, i - 3):i + 2]).lower()
            if not any(k in ctx_window for k in ALGOLIA_CONTEXT_KEYWORDS):
                continue
            # 跳过 String.fromEnvironment / --dart-define 合法注入
            if "fromenvironment" in line.lower():
                continue
            if ALGOLIA_APP_ID_PATTERN.search(line) or ALGOLIA_KEY_PATTERN.search(line):
                # 忽略明显占位符
                if any(m in line.lower() for m in EXAMPLE_MARKERS):
                    continue
                result.fail(
                    "GR-ALGOLIA-SECRET",
                    f"{f}:{i} -- {stripped[:80]}",
                    "Algolia credentials must be injected via "
                    "--dart-define=ALGOLIA_APP_ID=... / ALGOLIA_SEARCH_KEY=.... "
                    "Use String.fromEnvironment('ALGOLIA_APP_ID').")
                found = True
    if not found:
        print("  [OK] No hardcoded Algolia credentials.\n")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def check_all(src_dirs, docs_dir=None):
    """Run all golden rule checks. Returns (fail_count, warn_count, info_count)."""
    result = CheckResult()

    print("=" * 60)
    print("Golden Rules Check")
    print("=" * 60 + "\n")

    check_file_size(src_dirs, result)
    check_secrets(src_dirs, result)
    check_console_log(src_dirs, result)
    check_hardcoded_colors(src_dirs, result)
    check_algolia_secrets(src_dirs, result)

    if docs_dir:
        check_doc_freshness(docs_dir, src_dirs, result)
        check_invariant_coverage(docs_dir, result)

    print("=" * 60)
    print(f"Golden Rules Summary: {result.fails} FAIL, {result.warns} WARN, {result.infos} INFO")
    if result.fails > 0:
        print("Result: FAILED -- fix FAIL items before proceeding.")
    elif result.warns > 0:
        print("Result: PASSED with warnings -- review WARN items.")
    else:
        print("Result: PASSED")
    print("=" * 60)

    return result.fails, result.warns, result.infos


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python golden_rules.py <src_dir1> [src_dir2] ... [--docs <docs_dir>]")
        print("Example: python golden_rules.py src/ --docs .plans/myproject/docs")
        sys.exit(2)

    args = sys.argv[1:]
    docs = None
    src = []
    i = 0
    while i < len(args):
        if args[i] == "--docs" and i + 1 < len(args):
            docs = args[i + 1]
            i += 2
        else:
            src.append(args[i])
            i += 1

    fails, warns, infos = check_all(src, docs_dir=docs)
    sys.exit(1 if fails > 0 else 0)
