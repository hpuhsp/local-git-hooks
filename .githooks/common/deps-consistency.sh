#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/deps-consistency.sh — 告警：依赖清单改动提醒（Gradle / Maven）
# 永不阻断（exit 0）；只在构建脚本改动时温和提醒锁定依赖版本。
. "$(dirname "$0")/../lib/_lib.sh"

files=$(qg_changed_files "$@")
[ -z "$files" ] && exit 0

# Gradle：build.gradle(.kts) 改动但未同步 gradle.lockfile
if printf '%s\n' "$files" | grep -iqE '(^|/)build\.gradle(\.kts)?$' \
   && ! printf '%s\n' "$files" | grep -iqE '(^|/)gradle\.lockfile$'; then
  qg_warn "deps" "build.gradle 已改动；如新增/升级依赖，建议启用依赖锁定（gradle dependency locking）并一并提交 gradle.lockfile。"
fi

# Maven：pom.xml 改动（无独立 lockfile，温和提醒）
if printf '%s\n' "$files" | grep -iqE '(^|/)pom\.xml$'; then
  qg_info "deps" "pom.xml 改动：请确认依赖版本已锁定（建议配合 dependencyManagement / BOM）。"
fi

exit 0
