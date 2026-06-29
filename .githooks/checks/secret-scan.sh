#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/secret-scan.sh — 阻断：gitleaks 扫描暂存区秘密（规格 §3）
# 未安装 gitleaks 时：响亮告警但放行（本地是反馈层；硬门禁留给未来 CI）。
. "$(dirname "$0")/_lib.sh"

if ! qg_has gitleaks; then
  qg_warn "secret-scan" "未安装 gitleaks，跳过秘密扫描！强烈建议安装：
# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-06-29 | modified | DESKTOP-NEC290S\HSP ===
  winget install Gitleaks.Gitleaks  /  scoop install gitleaks  /  brew install gitleaks"
# === AI MODIFIED END ===
  exit 0
fi

# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-06-29 | modified | DESKTOP-NEC290S\HSP ===
# gitleaks 8.18+ 推荐 `git --staged`（标注 good for pre-commit）；旧版回退兼容的 `protect --staged`
if gitleaks git --help >/dev/null 2>&1; then
  set -- git --staged --no-banner --redact
else
  set -- protect --staged --no-banner --redact
fi

if gitleaks "$@"; then
# === AI MODIFIED END ===
  exit 0
fi
qg_fail "secret-scan" "gitleaks 检出疑似秘密（上方已 redact）。请移除后再提交；确为误报用 .gitleaksignore 豁免。"
exit $?
