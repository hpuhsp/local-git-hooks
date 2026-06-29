#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/format.sh — 自动修：按语言分流格式化本次 staged 文件（规格 §3）
#   - 工具缺失只告警跳过，绝不阻断（始终 exit 0）。
#   - 仅原地格式化；重新暂存交给 lefthook 的 stage_fixed（规避并行 git add 抢 index 锁）。
. "$(dirname "$0")/_lib.sh"

files=$(qg_changed_files "$@" | qg_existing_files)
[ -z "$files" ] && exit 0

pick() { printf '%s\n' "$files" | grep -iE "$1" || true; }

# Vue / TS / JS / JSON / CSS / HTML / MD / YAML → prettier
web=$(pick '\.(vue|ts|tsx|js|jsx|mjs|cjs|json|css|scss|less|html|md|markdown|ya?ml)$')
if [ -n "$web" ]; then
  if qg_has npx && npx --no-install prettier --version >/dev/null 2>&1; then
    printf '%s\n' "$web" | qg_xargs npx --no-install prettier --write --ignore-unknown >/dev/null 2>&1 \
      || qg_warn "format" "prettier 执行失败，已跳过"
  else
    qg_info "format" "未安装 prettier，跳过前端文件格式化（npm i -D prettier）"
  fi
fi

# Python → ruff format（退回 black）
py=$(pick '\.py$')
if [ -n "$py" ]; then
  if qg_has ruff; then
    printf '%s\n' "$py" | qg_xargs ruff format >/dev/null 2>&1 || qg_warn "format" "ruff format 失败"
  elif qg_has black; then
    printf '%s\n' "$py" | qg_xargs black -q >/dev/null 2>&1 || qg_warn "format" "black 失败"
  else
    qg_info "format" "未安装 ruff/black，跳过 Python 格式化"
  fi
fi

# Java → google-java-format（构建期 spotless 兜底，放 pre-push/CI）
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
    qg_info "format" "未安装 ktlint，跳过 Kotlin 格式化"
  fi
fi

exit 0
