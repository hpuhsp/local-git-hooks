#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/commit-title.sh — commit-msg：标题规范（Conventional Commits，纯 shell）
#   不依赖 commitlint / Node；用 POSIX 正则校验，零外部依赖。
#   warn-only 下降级为告警。merge/revert/fixup/squash 自动放行。
. "$(dirname "$0")/../lib/_lib.sh"
MSG_FILE="$1"

# 取首个非空、非注释行作为标题
title=$(sed -n '/^[[:space:]]*#/d; /[^[:space:]]/{p;q;}' "$MSG_FILE")
[ -z "$title" ] && exit 0

# 自动放行：合并 / 回滚 / rebase autosquash
case "$title" in
  "Merge "*|"Revert "*|"fixup! "*|"squash! "*|"amend! "*) exit 0 ;;
esac

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
# <type>(<scope 可选>)(! 可选): <描述>
if printf '%s' "$title" | grep -qE "^(${types})(\([a-z0-9._/-]+\))?!?: .+"; then
  exit 0
fi

qg_fail "commit-title" "标题不符合 Conventional Commits：
  $title

格式：<type>(<scope 可选>): <描述>
type ∈ ${types}
例：feat(pig): 新增育肥阶段统计 / fix: 修复登录空指针"
exit $?
