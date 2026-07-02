#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-02 | DESKTOP-NEC290S\HSP ===
# .githooks/common/commit-title.sh — commit-msg：标题规范 + 内容质量（纯 shell，零依赖）
#   ① 格式：<type>(<scope 可选>): <描述>（Conventional Commits）
#   ② 质量：挡掉"敷衍"描述（如 fix: bug / feat: wip / fix: 123 / fix: 修改）
#   warn-only 下降级为告警；merge/revert/fixup/squash 自动放行。
#   QG_TITLE_QUALITY=0 可只保留格式校验、关闭质量层。
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

# ① 格式校验
if ! printf '%s' "$title" | grep -qE "^(${types})(\([a-z0-9._/-]+\))?!?: .+"; then
  qg_fail "commit-title" "标题不符合 Conventional Commits：
  $title

格式：<type>(<scope 可选>): <描述>
type ∈ ${types}
例：feat(pig): 新增育肥阶段统计 / fix: 修复登录空指针"
  exit $?
fi

[ "${QG_TITLE_QUALITY:-1}" = "0" ] && exit 0

# ② 内容质量：提取并归一化描述（去 type(scope)!: 前缀、小写、去首尾空白/标点）
desc=$(printf '%s' "$title" | sed -E "s/^(${types})(\([a-z0-9._/-]+\))?!?:[[:space:]]*//")
norm=$(printf '%s' "$desc" | tr 'A-Z' 'a-z' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:punct:]]+$//; s/^[[:punct:]]+//; s/[[:space:]]+/ /g')

# 敷衍词黑名单：仅当"整个描述恰为其一"才拦，近零误报（可按团队增补）
deny='bug|bugs|bugfix|bug fix|fix|fixes|fixed|fixbug|update|updates|updated|change|changes|changed|edit|edits|modify|wip|tmp|temp|test|tests|testing|todo|misc|stuff|minor|cleanup|clean up|commit|commit code|code|done|ok|asdf|xxx|refactor|修改|修复|更新|提交|测试|调整|优化|改bug|改一下|修复bug|更新代码|提交代码|修改代码|优化代码|调整代码|临时提交'

reason=""
if [ -z "$norm" ]; then
  reason="描述不能为空或只是符号"
elif printf '%s' "$norm" | grep -qxE "(${deny})"; then
  reason="描述过于笼统/敷衍"
elif printf '%s' "$norm" | grep -qE '^[0-9]+$'; then
  reason="描述不能只是数字"
else
  # 纯 ASCII 描述才做最短长度约束（含中文交给黑名单，避免字节数误判）
  case "$norm" in
    *[!\ -~]*) : ;;
    *) [ "$(printf '%s' "$norm" | wc -m | tr -d ' ')" -lt 3 ] && reason="描述太短，说不清改了什么" ;;
  esac
fi

if [ -n "$reason" ]; then
  qg_fail "commit-title" "标题内容${reason}：
  $title

请写清「改了什么 / 为什么」，别用 bug/update/wip 之类占位词。
例：fix(login): 修复 token 过期后未刷新导致的 401
    feat(pig): 新增育肥阶段日增重统计"
  exit $?
fi
exit 0
