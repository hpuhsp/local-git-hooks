#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/protect-branch.sh — 阻断：禁止直接提交受保护分支
. "$(dirname "$0")/../lib/_lib.sh"

PROTECTED="${QG_PROTECTED_BRANCHES:-main master}"
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || true)

[ -z "$branch" ] && exit 0                          # detached HEAD：不拦
[ "${QG_ALLOW_COMMIT_TO_MAIN:-0}" = "1" ] && exit 0 # 显式逃生门

# 初始提交（空仓库 / 无父提交）放行：新仓库首次提交不应被卡，避免逼用户敲逃生门
git rev-parse --verify -q HEAD >/dev/null 2>&1 || exit 0

for p in $PROTECTED; do
  if [ "$branch" = "$p" ]; then
    qg_fail "no-commit-to-main" "禁止直接提交到受保护分支 '$branch'。
请切到特性分支再提交：  git switch -c feature/<your-change>
（确需直接提交：临时 QG_ALLOW_COMMIT_TO_MAIN=1 git commit ...）"
    exit $?
  fi
done
exit 0
