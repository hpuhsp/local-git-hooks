# 本地 Git Hooks（lefthook + AI 溯源）

本地**反馈/助手层**：基于 [lefthook](https://github.com/evilmartians/lefthook) 编排，提交即跑通用门禁（secret/格式/规范/依赖）+ **AI 溯源 trailer**。
设计原则：阻断档近零误报，其余告警或自动修；检查逻辑与编排可迁移，未来加 CI 零重写。

> 适用语言栈：Java / Vue / TS / Kotlin / JS / Python（多语言混合，按文件扩展名分流）。

## 一、安装

前置：本仓库须是 git 仓库（`git init`）。然后任选其一安装 `lefthook`：

```bash
npm i -D lefthook            # 方式 A：作为 dev 依赖（随后 npm install）
# brew install lefthook      # 方式 B：系统二进制（macOS）
# scoop install lefthook     # 方式 B：系统二进制（Windows）
```

一键激活：

```bash
make setup                              # Linux / macOS / git-bash
# 或   sh scripts/setup.sh
# 或   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # Windows 原生
```

`setup` 会：检测 `core.hooksPath` 冲突（避免覆盖 Husky 等）→ `lefthook install` → 赋脚本可执行权限 → 自检可选工具。

可选工具（缺失时对应检查**自动跳过/告警，不阻断**）：`gitleaks`、`prettier`、`ruff`/`black`、`ktlint`、`google-java-format`、`commitlint`（经 `npm install` 提供）。

## 二、各钩子做什么

| 钩子               | 检查                                                    | 档位                         |
| ------------------ | ------------------------------------------------------- | ---------------------------- |
| pre-commit         | gitleaks 秘密扫描                                       | **阻断**（未装则告警放行）   |
| pre-commit         | 合并冲突标记 `<<<<<<<`                                  | **阻断**                     |
| pre-commit         | 私钥/凭据文件（`*.pem/.key/.p12/.env` 等）              | **阻断**                     |
| pre-commit         | 禁止直接提交 `main`/`master`                            | **阻断**                     |
| pre-commit         | 按语言格式化（prettier/ruff/ktlint/google-java-format） | 自动修                       |
| pre-commit         | lockfile 一致性 / 新增依赖提醒                          | 告警                         |
| prepare-commit-msg | 预置 AI 三档选项 + 读工具自动信号                       | —                            |
| commit-msg         | **强制 `Signed-off-by`** + 生成 AI trailer              | **阻断**(signoff) / 柔性(AI) |
| commit-msg         | 标题规范（Conventional Commits）                        | 阻断（未装则跳过）           |
| post-commit        | 异步 AI 使用度量埋点                                    | 不阻塞                       |
| pre-push           | 受影响测试 / 类型检查（慢检查下沉于此）                 | **阻断**                     |

## 三、AI 参与度怎么报（两段式，覆盖率 100%）

1. **工具自动信号（优先）**：支持的 AI 工具设置环境变量即可，提交时自动生成 trailer：

   ```bash
   export QG_AI_DEGREE=co-authored                 # assisted | co-authored | generated
   export QG_AI_TOOL="claude-code/2.1 (claude-opus-4-8)"
   ```

2. **提交时自报（兜底）**：未给自动信号时，编辑器里会预置三档注释，**取消注释你选的一项**即可（兼容 GUI/IDE/命令行）：

   ```
   # ── AI 参与度（取消注释你选的一项，默认 none）──────────
   QG-AI: co-authored   # ← 去掉行首 "# " 即选中
   ```

| Trailer           | 含义                     | 力度                                |
| ----------------- | ------------------------ | ----------------------------------- |
| `Assisted-by:`    | AI 轻度协助（约 ≤33%）   | 柔性·鼓励                           |
| `Co-authored-by:` | AI 实质贡献（约 35–67%） | 柔性·鼓励                           |
| `Generated-by:`   | 主要由 AI 生成（67%+）   | 柔性·鼓励                           |
| `Signed-off-by:`  | **人类对正确性负责**     | **硬性·阻断**（自动补，几乎零负担） |

**两条铁律**：准确优先（默认 none、不逼人乱填，保住度量真实性）；问责兜底（每个提交必有 `Signed-off-by`）。

度量落在 `.git/ai-metrics.log`（`SHA \t AI档位 \t Signed-off-by \t 增删行`），位于 `.git/` 内，不进版本控制。

## 四、环境变量开关

| 变量                          | 作用                                                                      |
| ----------------------------- | ------------------------------------------------------------------------- |
| `QG_WARN_ONLY=1`              | **试点模式**：阻断级检查降级为「告警但放行」（规格 §6.7，全员推广前两周） |
| `QG_AI_DEGREE` / `QG_AI_TOOL` | AI 自动信号来源                                                           |
| `QG_ALLOW_COMMIT_TO_MAIN=1`   | 临时允许直接提交受保护分支                                                |
| `QG_PROTECTED_BRANCHES`       | 自定义受保护分支（默认 `main master`）                                    |
| `QG_DIFF_RANGE`               | 未来 CI 复用：把检查对象从暂存区切到 diff range（规格 §7）                |

## 五、目录结构

```
lefthook.yml                     # 编排：哪个检查挂哪个钩子、阻断/告警
Makefile / scripts/setup.*       # 一键安装
commitlint.config.js             # 标题规范
.githooks/
  prepare-commit-msg             # AI 三档模板 + 读自动信号
  commit-msg                     # Signed-off-by 阻断 + 生成 AI trailer
  post-commit                    # 异步度量埋点
  checks/
    _lib.sh                      # 共享库：warn-only / 文件清单解耦 / 日志
    secret-scan.sh               # gitleaks
    no-conflict-markers.sh       # 冲突标记
    block-sensitive-files.sh     # 私钥/凭据
    protect-branch.sh            # 禁 main
    format.sh                    # 按语言格式化
    deps-consistency.sh          # lockfile/依赖告警
    affected-tests.sh            # pre-push 测试/类型检查
    commit-title.sh              # commitlint 包装
```

## 六、未来接 CI（规格 §7）

检查逻辑已与「staged vs diff range」解耦：CI 里对 MR diff 设置 `QG_DIFF_RANGE="$CI_MERGE_REQUEST_DIFF_BASE_SHA...HEAD"`，同一批 `.githooks/checks/*.sh` 直接复用，零重写。
