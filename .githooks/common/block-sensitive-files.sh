#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/common/block-sensitive-files.sh — 阻断：私钥 / 凭据文件
# 按文件名判定；便于未来 CI / 全量扫描复用。
. "$(dirname "$0")/../lib/_lib.sh"

files=$(qg_changed_files "$@")
[ -z "$files" ] && exit 0

# 命中即拒：私钥 / 证书 / keystore / .env 系列 / SSH 私钥
hits=$(printf '%s\n' "$files" \
  | grep -iE '\.(pem|key|p12|pfx|jks|keystore)$|(^|/)\.env($|\.)|(^|/)id_(rsa|dsa|ecdsa|ed25519)$' \
  | grep -ivE '\.(example|sample|template|dist)$|(^|/)\.env\.(example|sample|template)$' \
  || true)

if [ -n "$hits" ]; then
  list=$(printf '%s\n' "$hits" | sed 's/^/  /')
  qg_fail "private-key" "检测到疑似私钥 / 凭据文件，禁止提交：
$list

若确为误报：重命名为 *.example，或在 .gitleaksignore 中显式豁免。"
  exit $?
fi
exit 0
