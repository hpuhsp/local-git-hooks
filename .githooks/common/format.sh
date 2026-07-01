#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/format.sh — 自动修：按语言分流格式化本次 staged 文件（JVM 栈）
#   - 仅 Java / Kotlin；工具缺失只告警跳过，绝不阻断（始终 exit 0）。
#   - 只原地格式化；重新暂存由 pre-commit dispatcher 负责。
#   - 未装本地工具时，Java/Kotlin 格式化可交给构建期 spotless / ktlint 插件。
. "$(dirname "$0")/../lib/_lib.sh"

files=$(qg_changed_files "$@" | qg_existing_files)
[ -z "$files" ] && exit 0

pick() { printf '%s\n' "$files" | grep -iE "$1" || true; }

# Java → google-java-format（构建期 spotless 兜底）
java=$(pick '\.java$')
if [ -n "$java" ]; then
  if qg_has google-java-format; then
    printf '%s\n' "$java" | qg_xargs google-java-format -i >/dev/null 2>&1 || qg_warn "format" "google-java-format 失败"
  else
    qg_info "format" "未安装 google-java-format，Java 格式化交给构建期 spotless"
  fi
fi

# Kotlin → ktlint -F
kt=$(pick '\.kts?$')
if [ -n "$kt" ]; then
  if qg_has ktlint; then
    printf '%s\n' "$kt" | qg_xargs ktlint -F >/dev/null 2>&1 || true   # -F 修复后可能仍返回非 0
  else
    qg_info "format" "未安装 ktlint，Kotlin 格式化交给构建期 ktlint 插件"
  fi
fi

exit 0
