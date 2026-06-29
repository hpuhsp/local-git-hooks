#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/commit-title.sh — commit-msg：标题规范（Conventional Commits via commitlint）
# 未安装 commitlint 时跳过（本地反馈层）；安装后不通过则阻断（warn-only 下降级告警）。
. "$(dirname "$0")/_lib.sh"
MSG_FILE="$1"

if ! qg_has npx || ! npx --no-install commitlint --version >/dev/null 2>&1; then
  qg_info "commitlint" "未安装 commitlint，跳过标题规范检查（npm i -D @commitlint/cli @commitlint/config-conventional）"
  exit 0
fi

if npx --no-install commitlint --edit "$MSG_FILE"; then
  exit 0
fi
qg_fail "commitlint" "提交标题不符合 Conventional Commits 规范，例：feat(scope): 简述。"
exit $?
