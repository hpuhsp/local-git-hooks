#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/no-large-files.sh — 阻断：新增/改动的大文件
#   阈值 QG_MAX_FILE_KB（默认 2048KB=2MB）；超过即拒，建议改用 Git LFS。
#   只看大小、不按"是否二进制"拦——后者误报高，违背"阻断档近零误报"。
. "$(dirname "$0")/../lib/_lib.sh"

MAX_KB="${QG_MAX_FILE_KB:-2048}"
files=$(qg_changed_files "$@" | qg_existing_files)
[ -z "$files" ] && exit 0

hits=$(printf '%s\n' "$files" | while IFS= read -r f; do
  # 优先取暂存区 blob 大小；取不到（CI/diff-range 场景）回退工作区文件大小
  size=$(git cat-file -s ":$f" 2>/dev/null)
  [ -z "$size" ] && size=$(wc -c <"$f" 2>/dev/null | tr -d ' ')
  [ -z "$size" ] && continue
  kb=$((size / 1024))
  [ "$kb" -gt "$MAX_KB" ] && printf '  %s (%s KB)\n' "$f" "$kb"
done)

if [ -n "$hits" ]; then
  qg_fail "large-file" "以下文件超过 ${MAX_KB}KB 阈值，禁止直接入库：
$hits

建议：用 Git LFS（git lfs track）或移出仓库。
确需提交：临时 QG_MAX_FILE_KB=<更大值> git commit ..."
  exit $?
fi
exit 0
