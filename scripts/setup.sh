#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# scripts/setup.sh — 安装并激活本地 git hooks（纯 core.hooksPath 文件夹工具集）
#   - 检测是否 git 仓库
#   - 侦测已有 .git/hooks 本地钩子，提示可能被 core.hooksPath 屏蔽
#   - git config core.hooksPath .githooks（激活；无需任何二进制/Node）
#   - 赋脚本可执行权限，best-effort 引导安装 gitleaks，自检可选工具
set -e

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ 当前目录不是 git 仓库。请先：git init" >&2
  exit 1
fi
cd "$(git rev-parse --show-toplevel)"

# ── 已有 hooksPath / 本地钩子冲突提示 ──────────────────────────
existing="$(git config --get core.hooksPath || true)"
if [ -n "$existing" ] && [ "$existing" != ".githooks" ]; then
  echo "⚠️  当前 core.hooksPath = '$existing'（如 Husky 的 .husky）。"
  echo "    继续将改为 .githooks；若需与现有方案并存，请先协调。"
fi
hookdir="$(git rev-parse --git-path hooks)"
if ls "$hookdir"/* >/dev/null 2>&1 && ls "$hookdir" | grep -qvE '\.sample$'; then
  echo "ℹ️  侦测到 $hookdir 下已有本地钩子；启用 core.hooksPath 后 git 将只走 .githooks，"
  echo "    原有钩子会被忽略。如仍需保留，请手动合并进 .githooks/。"
fi

# ── 激活：指向版本控制内的 .githooks ──────────────────────────
git config core.hooksPath .githooks
echo "▶ 已设置 core.hooksPath = .githooks"

# ── 赋可执行权限（Unix 必需；Windows 无害）─────────────────────
chmod +x .githooks/pre-commit .githooks/pre-push .githooks/commit-msg \
         .githooks/prepare-commit-msg .githooks/post-commit 2>/dev/null || true
chmod +x .githooks/lib/*.sh .githooks/common/*.sh 2>/dev/null || true
find .githooks/stacks -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# ── gitleaks 引导安装（唯一高价值阻断项；缺失时 best-effort 自动装，失败不阻断）──
if ! command -v gitleaks >/dev/null 2>&1 && [ "${QG_SKIP_TOOL_INSTALL:-0}" != "1" ]; then
  echo "▶ 未发现 gitleaks，尝试自动安装（设 QG_SKIP_TOOL_INSTALL=1 可跳过）..."
  if command -v winget >/dev/null 2>&1; then
    winget install --id Gitleaks.Gitleaks -e --accept-source-agreements --accept-package-agreements --disable-interactivity || true
  elif command -v scoop >/dev/null 2>&1; then
    scoop install gitleaks || true
  elif command -v brew >/dev/null 2>&1; then
    brew install gitleaks || true
  else
    echo "   未找到 winget/scoop/brew，请手动安装：https://github.com/gitleaks/gitleaks/releases"
  fi
fi

echo ""
echo "✅ hooks 已激活（无需 Node / lefthook）。可选工具自检（缺失项对应检查会跳过/告警，不阻断）："
check_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "   ✓ $1"
  else
    echo "   - $1（未安装）"
  fi
}
for t in gitleaks google-java-format ktlint; do check_tool "$t"; done
