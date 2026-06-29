#!/bin/sh
# === AI GENERATED FILE | claude-opus-4-8 | 2026-06-29 | DESKTOP-NEC290S\HSP ===
# .githooks/checks/affected-tests.sh — pre-push（阻断）：受影响测试 / 类型检查（规格 §3/§4）
#   慢检查下沉到 pre-push，保持 commit 秒级。未检测到可运行配置时跳过。
. "$(dirname "$0")/_lib.sh"

status=0
ran=0

# JS / TS：有 package.json 且定义了脚本就跑
if [ -f package.json ] && qg_has npx; then
  if grep -q '"typecheck"' package.json 2>/dev/null; then
    ran=1; npm run -s typecheck || qg_fail "typecheck" "类型检查未通过" || status=1
  elif [ -f tsconfig.json ] && npx --no-install tsc --version >/dev/null 2>&1; then
    ran=1; npx --no-install tsc --noEmit || qg_fail "typecheck" "tsc 类型检查未通过" || status=1
  fi
  if grep -q '"test"' package.json 2>/dev/null; then
    ran=1; npm test --silent || qg_fail "test" "JS/TS 测试未通过" || status=1
  fi
fi

# Python：pytest 可用且存在测试
if qg_has pytest && { [ -d tests ] || ls test_*.py >/dev/null 2>&1; }; then
  ran=1; pytest -q || qg_fail "pytest" "Python 测试未通过" || status=1
fi

# Gradle
if [ -x ./gradlew ]; then
  ran=1; ./gradlew -q test || qg_fail "gradle-test" "Gradle 测试未通过" || status=1
fi

# Maven
if [ -f pom.xml ] && qg_has mvn; then
  ran=1; mvn -q -DskipITs test || qg_fail "maven-test" "Maven 测试未通过" || status=1
fi

if [ "$ran" = "0" ]; then
  qg_info "affected-tests" "未检测到可运行的测试/类型检查配置，跳过（pre-push）。"
fi
exit $status
