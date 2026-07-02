#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/lib/_lib.sh — 本地 hook 共享工具函数
#
# 设计目标（留给未来 CI 的便宜后门）：
#   把"检查逻辑"与"staged vs diff range"解耦。脚本用同一套逻辑既能跑本地暂存区，
#   未来加 CI 时只需设置 QG_DIFF_RANGE 即可复用，零重写。

# ── warn-only 试点开关 ─────────────────────────────────────────
# QG_WARN_ONLY=1 时，阻断级检查降级为「告警但放行」，用于全员推广前两周试点。
qg_is_warn_only() { [ "${QG_WARN_ONLY:-0}" = "1" ]; }

# ── 命令探测 ────────────────────────────────────────────────
qg_has() { command -v "$1" >/dev/null 2>&1; }

# ── 统一日志（全部走 stderr，不污染脚本 stdout）──────────────────
qg_warn() { _n="$1"; shift; printf '⚠️  [%s] %s\n' "$_n" "$*" >&2; }
qg_info() { _n="$1"; shift; printf 'ℹ️  [%s] %s\n' "$_n" "$*" >&2; }

# 统一失败出口：
#   warn-only → 打印告警并返回 0（放行）
#   否则      → 打印错误并返回 1（阻断）
# 用法：  some_check || qg_fail "<name>" "<message>"
qg_fail() {
  _n="$1"; shift
  if qg_is_warn_only; then
    printf '⚠️  [%s] %s （warn-only，未阻断）\n' "$_n" "$*" >&2
    return 0
  fi
  printf '❌ [%s] %s\n' "$_n" "$*" >&2
  return 1
}

# ── 文件清单（解耦 staged / diff-range）─────────────────────────
# 返回本次要检查的文件（每行一个），按优先级：
#   1) QG_DIFF_RANGE 已设置（未来 CI）：git diff --name-only <range>
# === AI REPLACED BEGIN | claude-fable-5 | 2026-07-02 | replaced | DESKTOP-NEC290S\HSP ===
# [ORIGINAL]
# #   2) 否则有位置参数（透传的文件列表）：直接用之
# [/ORIGINAL]
#   2) 否则有位置参数（调用方显式传入，如栈叠加脚本 / 测试）：直接用之
# === AI REPLACED END ===

#   3) 否则退回当前暂存区：git diff --cached --name-only
qg_changed_files() {
  if [ -n "${QG_DIFF_RANGE:-}" ]; then
    git diff --name-only --diff-filter=ACMR "$QG_DIFF_RANGE"
  elif [ "$#" -gt 0 ]; then
    for _f in "$@"; do [ -n "$_f" ] && printf '%s\n' "$_f"; done
  else
    git diff --cached --name-only --diff-filter=ACMR
  fi
}

# 过滤出工作区里实际存在的普通文件（剔除已删除项）
qg_existing_files() {
  while IFS= read -r _f; do
    [ -n "$_f" ] && [ -f "$_f" ] && printf '%s\n' "$_f"
  done
}

# 可移植 xargs（处理含空格文件名；调用方需自行保证输入非空）
qg_xargs() { tr '\n' '\0' | xargs -0 "$@"; }
