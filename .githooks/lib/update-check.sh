#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-02 | DESKTOP-NEC290S\HSP ===
# .githooks/lib/update-check.sh — 限流的更新提示（只通知、绝不自改；安全考量见 README）
#   由 post-commit 后台调用。默认每天最多查一次；无网/无工具静默跳过。
#   开关：QG_NO_UPDATE_CHECK=1 关闭；QG_UPDATE_URL 覆盖版本源（测试/自建镜像用）。
[ "${QG_NO_UPDATE_CHECK:-0}" = "1" ] && exit 0

here="$(dirname "$0")"
# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-07-02 | modified | DESKTOP-NEC290S\HSP ===
localver="$(cat "$here/../VERSION" 2>/dev/null | tr -d '[:space:]')"
# === AI MODIFIED END ===

[ -z "$localver" ] && exit 0                      # 无本地版本戳（老仓库未重装）→ 不打扰

gitdir="$(git rev-parse --git-dir 2>/dev/null)" || exit 0

# ── 限流：24h 内查过就跳过 ──────────────────────────────────────
stamp="$gitdir/.hooks-update-check"
if [ -f "$stamp" ]; then
  now=$(date +%s 2>/dev/null || echo 0)
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  [ "$now" -gt 0 ] && [ $((now - last)) -lt 86400 ] && exit 0
fi
date +%s >"$stamp" 2>/dev/null || true

# ── 取远端版本（默认 GitHub raw；QG_UPDATE_URL 可覆盖，支持本地路径便于测试）──
src="${QG_UPDATE_URL:-https://raw.githubusercontent.com/hpuhsp/local-git-hooks/master/.githooks/VERSION}"
case "$src" in
  http://*|https://*)
    if command -v curl >/dev/null 2>&1; then
      remote="$(curl -fsSL --max-time 5 "$src" 2>/dev/null)"
    elif command -v wget >/dev/null 2>&1; then
      remote="$(wget -qO- --timeout=5 "$src" 2>/dev/null)"
    else
      exit 0
    fi ;;
  *) remote="$(cat "$src" 2>/dev/null)" ;;        # 本地路径（测试 / 自建分发）
esac
remote="$(printf '%s' "$remote" | tr -d '[:space:]')"
[ -z "$remote" ] && exit 0                         # 拉取失败 → 静默

if [ "$remote" != "$localver" ]; then
  printf '🔔 [hooks] 有新版可用：本地 %s → 远端 %s\n' "$localver" "$remote" >&2
  printf '   更新：curl -fsSL https://raw.githubusercontent.com/hpuhsp/local-git-hooks/master/install.sh | sh\n' >&2
fi
exit 0
