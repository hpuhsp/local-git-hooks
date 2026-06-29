#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/no-conflict-markers.sh — 阻断：未解决的合并冲突标记（规格 §3）
. "$(dirname "$0")/_lib.sh"

files=$(qg_changed_files "$@" | qg_existing_files)
[ -z "$files" ] && exit 0

# 只匹配 git 冲突标记的确定性形态，近零误报：
#   "<<<<<<< ref"  |  "||||||| ref"  |  整行 "======="  |  ">>>>>>> ref"
pattern='^(<<<<<<< |\|\|\|\|\|\|\| |>>>>>>> |=======$)'

hits=$(printf '%s\n' "$files" | while IFS= read -r f; do
  if grep -IqE "$pattern" "$f" 2>/dev/null; then printf '  %s\n' "$f"; fi
done)

if [ -n "$hits" ]; then
  qg_fail "merge-conflict" "以下文件残留冲突标记，请解决后再提交：
$hits"
  exit $?
fi
exit 0
