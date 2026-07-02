#!/bin/sh
# === AI GENERATED FILE | claude-fable-5 | 2026-07-02 | DESKTOP-NEC290S\HSP ===
# tests/run-tests.sh — 钩子回归测试（POSIX sh；git-bash / Linux / macOS 均可跑）
# 用法：  sh tests/run-tests.sh
# 机制：在临时目录建真实 git 仓库、激活 .githooks，逐场景断言「应放行 / 应拦截」。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/qg-hooks-XXXXXX")"
# === AI REPLACED BEGIN | claude-fable-5 | 2026-07-02 | replaced | DESKTOP-NEC290S\HSP ===
# [ORIGINAL]
# trap 'rm -rf "$TMP"' EXIT
# [/ORIGINAL]
# 清理前稍候：post-commit 后台度量进程可能仍占用临时仓库目录
trap 'cd "$ROOT" && sleep 1 && rm -rf "$TMP" 2>/dev/null' EXIT
# === AI REPLACED END ===


# ── 隔离环境：不读全局/系统 git 配置，清空所有 QG_ 开关 ──────────
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset QG_WARN_ONLY QG_AI_DEGREE QG_AI_TOOL QG_AI_EMAIL QG_DIFF_RANGE \
  QG_PROFILE QG_ALLOW_COMMIT_TO_MAIN QG_MAX_FILE_KB QG_PROTECTED_BRANCHES \
  QG_SKIP_TOOL_INSTALL 2>/dev/null || true

PASS=0
FAIL=0

ok() { # ok <描述> <shell 串>：期望退出码 0（放行）
  _d="$1"
  shift
  if sh -c "$*" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  \342\234\223 %s\n' "$_d"
  else
    FAIL=$((FAIL + 1))
    printf '  \342\234\227 %s\357\274\210\346\234\237\346\234\233\351\200\232\350\277\207\357\274\214\345\256\236\351\231\205\350\242\253\346\213\222\357\274\211\n' "$_d"
  fi
}
ko() { # ko <描述> <shell 串>：期望退出码非 0（拦截）
  _d="$1"
  shift
  if sh -c "$*" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    printf '  \342\234\227 %s\357\274\210\346\234\237\346\234\233\350\242\253\346\213\222\357\274\214\345\256\236\351\231\205\351\200\232\350\277\207\357\274\211\n' "$_d"
  else
    PASS=$((PASS + 1))
    printf '  \342\234\223 %s\n' "$_d"
  fi
}

new_repo() { # new_repo <名字>：建临时仓库并激活钩子，cd 进入
  _r="$TMP/$1"
  mkdir -p "$_r"
  cd "$_r"
  git init -q
  git symbolic-ref HEAD refs/heads/master
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config commit.gpgsign false
  cp -r "$ROOT/.githooks" .
  git config core.hooksPath .githooks
}

# ════ A. 分支保护 ════════════════════════════════════════════
echo "A. 分支保护"
new_repo repo-a
echo hello >a.txt
ok "A1 初始提交到 master 放行（初始豁免）" 'git add -A && git commit -q -m "chore: init"'
ok "A2 Signed-off-by 已自动追加" 'git log -1 --format=%B | grep -q "^Signed-off-by: Test User <test@example.com>"'
echo x >b.txt
ko "A3 非初始提交到 master 被拒" 'git add -A && git commit -q -m "chore: second"'
ok "A4 QG_ALLOW_COMMIT_TO_MAIN=1 逃生门放行" 'export QG_ALLOW_COMMIT_TO_MAIN=1; git commit -q -m "chore: second"'
ok "A5 特性分支提交放行" 'git checkout -q -b feature/x && echo y >c.txt && git add -A && git commit -q -m "feat: c"'
ko "A6 QG_PROTECTED_BRANCHES 自定义保护 develop" 'git checkout -q -b develop && echo z >d.txt && git add -A && export QG_PROTECTED_BRANCHES="main master develop"; git commit -q -m "feat: d"'
git reset -q 2>/dev/null
rm -f d.txt
git checkout -q feature/x

# ════ B. 提交标题（Conventional Commits，单元级） ══════════════
echo "B. 提交标题"
MSG="$TMP/msg.txt"
w() { printf '%s\n' "$1" >"$MSG"; }
CT="$ROOT/.githooks/common/commit-title.sh"
w 'feat(pig): 新增育肥统计'
ok "B1 feat(scope) 放行" "sh '$CT' '$MSG'"
w 'fix: 修复登录空指针'
ok "B2 fix 放行" "sh '$CT' '$MSG'"
w 'refactor(hooks)!: 破坏性变更'
ok "B3 带 ! 破坏性标记放行" "sh '$CT' '$MSG'"
w "Merge branch 'develop'"
ok "B4 Merge 提交放行" "sh '$CT' '$MSG'"
w 'Revert "feat: x"'
ok "B5 Revert 提交放行" "sh '$CT' '$MSG'"
w 'fixup! feat: x'
ok "B6 fixup! 放行" "sh '$CT' '$MSG'"
w '随手改了点东西'
ko "B7 随意中文标题被拒" "sh '$CT' '$MSG'"
w 'update readme'
ko "B8 非规范英文标题被拒" "sh '$CT' '$MSG'"
w 'feat 缺少冒号'
ko "B9 缺冒号被拒" "sh '$CT' '$MSG'"

# ════ C. 冲突标记 / 大文件 / 敏感文件 ═══════════════════════════
echo "C. 冲突标记 / 大文件 / 敏感文件"
printf '<<<<<<< HEAD\nx\n=======\ny\n>>>>>>> b\n' >conflict.txt
ko "C1 冲突标记被拒" 'git add conflict.txt && git commit -q -m "fix: conflict"'
ok "C2 QG_WARN_ONLY=1 试点降级放行" 'export QG_WARN_ONLY=1; git commit -q -m "fix: warn-only"'
printf 'a == b\n==== section ====\n========\n' >eq.txt
ok "C3 普通等号不误报" 'git add eq.txt && git commit -q -m "docs: eq"'
head -c 4096 /dev/zero >big.bin
ko "C4 大文件超阈值被拒" 'export QG_MAX_FILE_KB=2; git add big.bin && git commit -q -m "chore: big"'
ok "C5 QG_MAX_FILE_KB 提升阈值放行" 'export QG_MAX_FILE_KB=100000; git commit -q -m "chore: big ok"'
echo x >.env
ko "C6 .env 被拒" 'git add .env && git commit -q -m "chore: env"'
git reset -q
rm -f .env
ok "C7 .env.example 豁免放行" 'echo x >.env.example && git add .env.example && git commit -q -m "chore: env example"'
echo k >release.jks
ko "C8 keystore(.jks) 被拒" 'git add release.jks && git commit -q -m "chore: jks"'
git reset -q
rm -f release.jks
echo k >id_rsa
ko "C9 SSH 私钥 id_rsa 被拒" 'git add id_rsa && git commit -q -m "chore: rsa"'
git reset -q
rm -f id_rsa

# ════ D. AI trailer / Signed-off-by ═══════════════════════════
echo "D. AI trailer / Signed-off-by"
ok "D1 QG_AI_DEGREE=generated 生成 Generated-by" 'export QG_AI_DEGREE=generated QG_AI_TOOL=claude-code; echo 1 >d1.txt && git add d1.txt && git commit -q -m "feat: d1" && git log -1 --format=%B | grep -q "^Generated-by: claude-code <ai@noreply.local>"'
ok "D2 AI_TOOL 自带邮箱不重复追加" 'export QG_AI_DEGREE=assisted QG_AI_TOOL="bot <b@x.y>"; echo 2 >d2.txt && git add d2.txt && git commit -q -m "feat: d2" && git log -1 --format=%B | grep -q "^Assisted-by: bot <b@x.y>$"'
ok "D3 QG-AI 自报行生成 Co-authored-by" 'echo 3 >d3.txt && git add d3.txt && git commit -q -m "feat: d3" -m "QG-AI: co-authored" && git log -1 --format=%B | grep -q "^Co-authored-by: unknown <ai@noreply.local>$"'
ok "D4 QG-AI 行已从正文清除" '! git log -1 --format=%B | grep -q "^QG-AI:"'
ok "D5 默认 none 不写 AI trailer" 'echo 5 >d5.txt && git add d5.txt && git commit -q -m "feat: d5" && ! git log -1 --format=%B | grep -qE "^(Assisted|Generated|Co-authored)-by:"'
ok "D6 未知 QG_AI_DEGREE 忽略并放行" 'export QG_AI_DEGREE=bogus; echo 6 >d6.txt && git add d6.txt && git commit -q -m "feat: d6" && ! git log -1 --format=%B | grep -qE "^(Assisted|Generated|Co-authored)-by:"'
ok "D7 模板注释行已清理" '! git log -1 --format=%B | grep -qE "QG-AI|^# ─"'
ok "D8 -s 签名不重复追加" 'echo 8 >d8.txt && git add d8.txt && git commit -q -s -m "feat: d8" && [ "$(git log -1 --format=%B | grep -c "^Signed-off-by:")" = "1" ]'
ko "D9 不规范标题被拒（集成）" 'echo 9 >d9.txt && git add d9.txt && git commit -q -m "随手改一下"'
git reset -q
rm -f d9.txt

# ════ E. merge 跳过 / pre-push / 度量 ══════════════════════════
echo "E. merge 跳过 / pre-push / 度量"
ok "E1 MERGE_HEAD 存在时 pre-commit 整体跳过" 'touch .git/MERGE_HEAD && printf "<<<<<<< HEAD\n" >m.txt && git add m.txt && sh .githooks/pre-commit; rc=$?; rm -f .git/MERGE_HEAD; git reset -q; rm -f m.txt; exit $rc'
ok "E2 pre-push 无慢检查直接放行" 'sh .githooks/pre-push'
ok "E3 post-commit 度量已落盘" 'sleep 1; [ -s .git/ai-metrics.log ]'
ok "E4 度量记录含 AI 工具名" 'grep -q "claude-code" .git/ai-metrics.log'

# ════ F. 栈侦测 detect.sh ═════════════════════════════════════
echo "F. 栈侦测"
new_repo repo-android
cat >build.gradle <<'EOF'
plugins { id 'com.android.application' }
EOF
ok "F1 侦测 android（AGP 插件）" '[ "$(sh .githooks/lib/detect.sh)" = "android" ]'
ok "F2 QG_PROFILE 覆盖侦测" 'export QG_PROFILE=java; [ "$(sh .githooks/lib/detect.sh)" = "java" ]'
echo java >.githooks.profile
ok "F3 .githooks.profile 覆盖侦测" '[ "$(sh .githooks/lib/detect.sh)" = "java" ]'
rm -f .githooks.profile

new_repo repo-java
touch pom.xml
ok "F4 侦测 java（pom.xml）" '[ "$(sh .githooks/lib/detect.sh)" = "java" ]'
new_repo repo-plain
ok "F5 未知栈输出为空" '[ -z "$(sh .githooks/lib/detect.sh)" ]'

# ════ G. 栈叠加执行 ═══════════════════════════════════════════
echo "G. 栈叠加"
cd "$TMP/repo-java"
ok "G0 java 仓初始提交放行" 'git add -A && git commit -q -m "chore: init"'
git checkout -q -b feature/g
cat >.githooks/stacks/java/pre-commit.d/block.sh <<'EOF'
#!/bin/sh
exit 1
EOF
ko "G1 pre-commit 栈叠加脚本失败可阻断" 'echo g >g.txt && git add g.txt && git commit -q -m "feat: g"'
rm -f .githooks/stacks/java/pre-commit.d/block.sh
ok "G2 移除叠加脚本后放行" 'git commit -q -m "feat: g"'
cat >.githooks/stacks/java/pre-push.d/fail.sh <<'EOF'
#!/bin/sh
exit 1
EOF
ko "G3 pre-push 栈叠加可阻断" 'sh .githooks/pre-push'
rm -f .githooks/stacks/java/pre-push.d/fail.sh
ok "G4 移除后 pre-push 恢复放行" 'sh .githooks/pre-push'

# ════ H. gitleaks 秘密扫描（本机装了才跑） ══════════════════════
if command -v gitleaks >/dev/null 2>&1; then
  echo "H. gitleaks 秘密扫描"
# === AI REPLACED BEGIN | claude-fable-5 | 2026-07-02 | replaced | DESKTOP-NEC290S\HSP ===
# [ORIGINAL]
#   # 伪造凭据：拼接构造，防止本文件自身被扫中
#   fake="ghp_""aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
# [/ORIGINAL]
  # 伪造凭据：拼接构造防止本文件自身被扫中；须用乱序串（顺序串会命中 gitleaks 假样本豁免）
  fake="ghp_""Zx9Qw2Rt7Yu4Io1Pl8Kj3Hg6Fd5Sa0MnVb4C"
# === AI REPLACED END ===

  printf 'github_pat = "%s"\n' "$fake" >leak.txt
  ko "H1 伪造 GitHub PAT 被拒" 'git add leak.txt && git commit -q -m "chore: leak"'
  git reset -q
  rm -f leak.txt
  ok "H2 移除秘密后放行" 'echo clean >clean.txt && git add clean.txt && git commit -q -m "chore: clean"'
else
  echo "H. gitleaks 未安装，跳过（不计入统计）"
fi

# ════ 汇总 ════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL))
RATE=$((PASS * 100 / TOTAL))
echo ""
echo "════════════════════════════════"
printf '通过 %d / %d（%d%%）\n' "$PASS" "$TOTAL" "$RATE"
[ "$FAIL" = "0" ] || exit 1
