#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/deps-consistency.sh — 告警：lockfile 一致性 / 新增依赖提醒（规格 §3）
# 永不阻断（exit 0）；只在 manifest 改动而 lockfile 未同步时提醒。
. "$(dirname "$0")/_lib.sh"

files=$(qg_changed_files "$@")
[ -z "$files" ] && exit 0

# $1 描述  $2 manifest 正则  $3 lockfile 正则
warn_pair() {
  if printf '%s\n' "$files" | grep -iqE "$2" && ! printf '%s\n' "$files" | grep -iqE "$3"; then
    qg_warn "deps" "$1 已改动但未同步对应 lockfile；如新增/升级依赖，请重新生成锁文件后一并提交。"
  fi
}

# JS / TS
warn_pair "package.json"       '(^|/)package\.json$'          '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$'
# Python（poetry）
warn_pair "pyproject.toml"     '(^|/)pyproject\.toml$'        '(^|/)poetry\.lock$'
# Java / Kotlin（gradle）
warn_pair "build.gradle(.kts)" '(^|/)build\.gradle(\.kts)?$'  '(^|/)gradle\.lockfile$'
# Java（maven，无独立 lockfile：仅在 pom 改动时温和提醒）
if printf '%s\n' "$files" | grep -iqE '(^|/)pom\.xml$'; then
  qg_info "deps" "pom.xml 改动：请确认依赖版本已锁定（建议配合 dependency 管理/BOM）。"
fi

exit 0
