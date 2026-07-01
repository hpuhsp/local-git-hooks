#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-07-01 | DESKTOP-NEC290S\HSP ===
# .githooks/lib/detect.sh — 侦测项目技术栈，输出：android | java | （空=未知）
#   约定优先、侦测为主：
#     1) 环境变量 QG_PROFILE 显式指定 → 直接采用（逃生门）
#     2) 仓库根 .githooks.profile 首个非注释行 → 采用（团队可提交固定）
#     3) 否则按构建文件自动侦测：含 Android Gradle 插件 → android；有 pom/gradle → java
#   多语言混合仓可留空，让「按扩展名分流」的通用检查自行处理。

if [ -n "${QG_PROFILE:-}" ]; then
  printf '%s\n' "$QG_PROFILE"
  exit 0
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -f "$root/.githooks.profile" ]; then
  sed -n 's/^[[:space:]]*//; /^#/d; /./{p;q;}' "$root/.githooks.profile"
  exit 0
fi

# Android：任一 build.gradle(.kts) 里出现 com.android.application/library 插件
if grep -rqsE 'com\.android\.(application|library)' \
     --include=build.gradle --include=build.gradle.kts "$root" 2>/dev/null; then
  echo android
elif [ -f "$root/pom.xml" ] || [ -f "$root/build.gradle" ] || [ -f "$root/build.gradle.kts" ]; then
  echo java
fi
