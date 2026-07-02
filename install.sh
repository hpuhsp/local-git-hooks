#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-02 | DESKTOP-NEC290S\HSP ===
# install.sh — 一键把本 hooks 工具集接入「当前 git 仓库」（最小侵入：只落 .githooks/ + 一行 config）
#
# 远程：curl -fsSL https://raw.githubusercontent.com/hpuhsp/local-git-hooks/master/install.sh | sh
# 本地：sh install.sh                         （在目标仓库根目录运行）
# 离线：QG_LOCAL_SRC=/path/to/kit sh install.sh
# 卸载：sh install.sh --uninstall
# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-07-02 | modified | DESKTOP-NEC290S\HSP ===
# 发版：sh install.sh --bump [版本]   （maintainer 用；在工具集仓库根 bump VERSION）
# === AI MODIFIED END ===
# 变量：QG_REF=<分支/tag>（默认 master）
set -eu

REPO="https://github.com/hpuhsp/local-git-hooks.git"
REF="${QG_REF:-master}"

git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "❌ 请在 git 仓库根目录运行（先 git init）" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)"

# ── 卸载 ──────────────────────────────────────────────────────
if [ "${1:-}" = "--uninstall" ]; then
  git config --unset core.hooksPath 2>/dev/null || true
  echo "✅ 已停用（git config --unset core.hooksPath）。.githooks/ 目录仍在，如需彻底移除请手动删除。"
  exit 0
# === AI MODIFIED BEGIN | claude-opus-4-8 | 2026-07-02 | modified | DESKTOP-NEC290S\HSP ===
fi

# ── 发版 bump：更新 .githooks/VERSION（maintainer 在工具集仓库根运行）──
if [ "${1:-}" = "--bump" ]; then
  vf=".githooks/VERSION"
  [ -f "$vf" ] || { echo "❌ 未找到 $vf（请在工具集仓库根运行 --bump）" >&2; exit 1; }
  old="$(tr -d '[:space:]' <"$vf")"
  if [ -n "${2:-}" ]; then
    new="$2"                                   # 显式指定版本
  else
    today="$(date +%Y.%m.%d)"                  # 默认取当天；同日再 bump 则递增后缀
    case "$old" in
      "$today")   new="$today.1" ;;
      "$today".*) new="$today.$(( ${old##*.} + 1 ))" ;;
      *)          new="$today" ;;
    esac
  fi
  printf '%s\n' "$new" >"$vf"
  echo "▶ VERSION: $old → $new"
  echo "  下一步：git add .githooks/VERSION && git commit -m \"chore(release): $new\" && git push"
  exit 0
# === AI MODIFIED END ===
fi

# ── 取得工具集来源：本地指定 / 远程克隆 ─────────────────────────
if [ -n "${QG_LOCAL_SRC:-}" ]; then
  SRC="$QG_LOCAL_SRC"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "▶ 拉取工具集（$REF）..."
  git clone --depth 1 --branch "$REF" "$REPO" "$TMP/kit" >/dev/null 2>&1 \
    || { echo "❌ 克隆失败，检查网络/代理后重试" >&2; exit 1; }
  SRC="$TMP/kit"
fi
[ -f "$SRC/.githooks/pre-commit" ] || { echo "❌ 工具集来源无效：$SRC" >&2; exit 1; }

# ── 写入 .githooks/（覆盖同名、保留你自加的 stacks 脚本，幂等更新）──
mkdir -p .githooks
cp -R "$SRC/.githooks/." ".githooks/"
echo "▶ 已写入 .githooks/"

# ── 合并 .gitattributes 的 LF 规则（幂等，不重复）──────────────
for line in ".githooks/** text eol=lf" "*.sh text eol=lf"; do
  grep -qxF "$line" .gitattributes 2>/dev/null || printf '%s\n' "$line" >>.gitattributes
done

# ── 激活（复用工具集自带 setup.sh：config + 赋权 + gitleaks 引导 + 自检）──
sh "$SRC/scripts/setup.sh"

echo ""
echo "✅ 接入完成。提交生效：git add .githooks .gitattributes && git commit -m \"chore: 接入本地 git hooks\""
