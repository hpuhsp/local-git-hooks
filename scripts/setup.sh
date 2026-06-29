#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# scripts/setup.sh — 安装并激活本地 git hooks（规格 §2/§6.1）
#   - 检测 git 仓库与 core.hooksPath 冲突（避免覆盖 Husky 等）
#   - 找到 lefthook（系统二进制或 npx 本地依赖）并执行 lefthook install
#   - 赋予 hook 脚本可执行权限，自检可选工具
set -e

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ 当前目录不是 git 仓库。请先：git init" >&2
  exit 1
fi
cd "$(git rev-parse --show-toplevel)"

# ── hooksPath 冲突检测 ─────────────────────────────────────
existing="$(git config --get core.hooksPath || true)"
if [ -n "$existing" ]; then
  echo "⚠️  检测到 core.hooksPath = '$existing'。"
  echo "    lefthook 默认安装到 .git/hooks；若 core.hooksPath 指向别处（如 Husky 的 .husky），"
  echo "    git 将忽略 lefthook 的 hooks。请先协调："
  echo "      git config --unset core.hooksPath   # 或与现有方案合并"
fi

# ── 定位 lefthook ─────────────────────────────────────────
if command -v lefthook >/dev/null 2>&1; then
  LEFTHOOK="lefthook"
elif command -v npx >/dev/null 2>&1 && npx --no-install lefthook version >/dev/null 2>&1; then
  LEFTHOOK="npx --no-install lefthook"
else
  echo "❌ 未找到 lefthook，请任选其一安装后重试：" >&2
  echo "    - npm i -D lefthook   然后 npm install" >&2
  echo "    - brew install lefthook / scoop install lefthook / winget install evilmartians.lefthook" >&2
  exit 1
fi

# ── 赋可执行权限（Unix 必需；Windows 无害）─────────────────────
chmod +x .githooks/commit-msg .githooks/prepare-commit-msg .githooks/post-commit 2>/dev/null || true
chmod +x .githooks/checks/*.sh scripts/*.sh 2>/dev/null || true

echo "▶ lefthook install ..."
$LEFTHOOK install

echo ""
echo "✅ hooks 已激活。可选工具自检（缺失项对应检查会跳过/告警，不阻断）："
# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-06-29 | modified | DESKTOP-NEC290S\HSP ===
check_tool() { # 全局 PATH 或 npm 本地依赖（node_modules）任一可用即视为可用
  if command -v "$1" >/dev/null 2>&1; then
    echo "   ✓ $1（全局）"
  elif command -v npx >/dev/null 2>&1 && npx --no-install "$1" --version >/dev/null 2>&1; then
    echo "   ✓ $1（本地 node_modules）"
  else
    echo "   - $1（未安装）"
  fi
}
for t in gitleaks prettier commitlint ruff black ktlint google-java-format; do check_tool "$t"; done
# === AI MODIFIED END ===

