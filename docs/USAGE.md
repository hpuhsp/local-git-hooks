# 本地 Git Hooks —— 项目说明与使用配置指南

> 配套精简版见仓库根 [`README.md`](../README.md)；本手册补充接入步骤、故障排查、场景速查等展开内容。

---

## 一、项目说明

### 1.1 这是什么

一套**纯本地、纯文件夹**的 git 钩子工具集：一个 `.githooks/` 目录 + 一行 `git config core.hooksPath .githooks` 即激活。提交/推送时自动跑通用门禁（秘密扫描、大文件、冲突标记、分支保护、格式化、提交规范）并写入 **AI 溯源 trailer**，沉淀"谁 / AI 参与了多少 / 谁担责"的度量。

**零依赖**：不需要 Node / npm / lefthook，`cp -r .githooks/` 进任何仓库即用——对 Android / Java 后端项目**零侵入**。

**设计定位**：本地钩子是**反馈 / 助手层**，不是强制门禁——

- 阻断档（exit≠0）只放**确定性、近零误报**的检查；
- 其余**告警**或**自动修**；
- 检查逻辑与"staged vs diff range"解耦，未来接 CI 几小时即可复用，零重写。

**适用范围**：**Android（Java+Kotlin+Gradle）+ Java 后端（Maven/Gradle）**。前端 Vue/uni-app 请用 Husky（Node 生态已有成熟方案，不在本工具集范围）。

### 1.2 架构（通用层 + 栈叠加 + 触发链路）

两个 JVM 栈之间的真实差异很小（主要是"用哪个格式化器"），故设计成 **一层厚通用 + 一层薄叠加**，差异优先用**自动侦测**消化：

| 层             | 角色                                                       | 产物                                     |
| -------------- | ---------------------------------------------------------- | ---------------------------------------- |
| 编排层         | 薄 dispatcher，git 通过 `core.hooksPath` 直接调用          | `.githooks/{pre-commit,pre-push,commit-msg,...}` |
| 通用层         | 全栈通用检查（占 90%），永远跑                             | `.githooks/common/*.sh`                  |
| 栈叠加层       | 栈专属额外规则，按侦测结果自动叠加（默认空）              | `.githooks/stacks/<android\|java>/`      |
| 共享库         | warn-only / 文件清单解耦 / 栈侦测                          | `.githooks/lib/{_lib.sh,detect.sh}`      |

```
git commit / git push
   └─ git 经 core.hooksPath 直接调用 .githooks/<hook>
      ├─ pre-commit          protect-branch / secret-scan / merge-conflict / large-file
      │                      / private-key / deps / format  +  stacks/<栈>/pre-commit.d/*
      │                      （merge/rebase 时整体跳过）
      ├─ prepare-commit-msg  预置 AI 三档选项 + 读工具自动信号
      ├─ commit-msg          commit-title（纯 shell）→ Signed-off-by（阻断）+ AI trailer
      ├─ post-commit         异步写 AI 使用度量（.git/ai-metrics.log）
      └─ pre-push            stacks/<栈>/pre-push.d/*（默认空，测试/编译交 CI）
```

### 1.3 技术选型

| 维度     | 选择                                                                          |
| -------- | ----------------------------------------------------------------------------- |
| 分发     | **纯 `core.hooksPath` 文件夹**（零二进制、零 Node，`cp` 即用、人人可读）       |
| 秘密扫描 | **gitleaks**（`git --staged`，8.18+ 语法，旧版回退 `protect`）                |
| 提交规范 | **纯 shell 正则**校验 Conventional Commits（不依赖 commitlint / Node）         |
| 格式化   | 按扩展名分流：`.java`→google-java-format，`.kt`→ktlint（缺失则交构建期插件）   |
| 栈侦测   | `build.gradle` 含 `com.android.*`→android；有 `pom.xml`/`build.gradle`→java   |
| AI 信号  | 两段式：工具自动信号（环境变量）优先，提交时取消注释自报兜底                   |
| Trailer  | AI 三档（柔性·鼓励）+ `Signed-off-by`（硬性·阻断）                            |

---

## 二、使用与配置指南

### 2.1 快速开始（本仓库 / 全新仓库）

```bash
git init                 # 若尚不是 git 仓库
sh scripts/setup.sh      # = git config core.hooksPath .githooks + 引导装 gitleaks + 权限 + 自检
```

Windows 原生：`powershell -ExecutionPolicy Bypass -File scripts\setup.ps1`。

### 2.2 接入到已有开发项目（最小侵入）

把这套钩子搬进**另一个已在开发的 Android / Java 项目**时，**不动业务代码**，只做加法。所有命令都在**目标项目根目录**（有 `.git` 的那层）执行。

**第 1 步 · 拷入文件**

| 必带（核心）                    | 可选                                        |
| ------------------------------- | ------------------------------------------- |
| `.githooks/`（整个目录）        | `scripts/setup.*`、`Makefile`（安装便捷脚本）|
| —                               | `.gitattributes` 的 LF 规则（无则新建，有则并入）|
| —                               | `.gitignore` 的 secrets 段（并入几行）      |

> **不需要**任何 `package.json` / `lefthook.yml` / `commitlint.config.js`——它们已被移除。
>
> `.gitattributes` 建议并入（防 Windows 下 CRLF 破坏 shebang）：
>
> ```
> .githooks/** text eol=lf
> *.sh text eol=lf
> ```

**第 2 步 · 激活并提交**

```bash
sh scripts/setup.sh                              # 或直接 git config core.hooksPath .githooks
git add .githooks .gitattributes                 # 连同上面拷入的文件
git commit -m "chore: 接入本地 git hooks"
```

提交后，团队每位成员拉到这些文件，各自跑一次 `sh scripts/setup.sh`（本质就是一行 `git config`）即生效。

> **侵入面**：本质是「1 个目录 `.githooks/` + 一行 `git config` + 几行合并」。**无 Node、无二进制**。激活状态写在本地 `.git/config`（不入库），故每个 clone 需各自跑一次 setup。
>
> **唯一冲突点**：项目已用 Husky 时 `core.hooksPath` 已被占用（指向 `.husky`），`setup` 会检测并提示；启用本工具集会让 git 只走 `.githooks`，原有 `.git/hooks` 下的本地钩子被忽略，需手动合并。

**第 3 步 · 按需固定技术栈（可选）**

自动侦测通常够用；若侦测不准或想显式声明，在仓库根建 `.githooks.profile`：

```
# 首个非注释行即技术栈
android
```

### 2.3 前置与可选依赖

| 工具                        | 必需？   | 缺失时行为                   | 安装                                                |
| --------------------------- | -------- | ---------------------------- | --------------------------------------------------- |
| git                         | ✅ 必需  | —                            | —                                                   |
| sh（git-bash 自带）         | ✅ 必需  | —                            | Windows 用 Git for Windows 自带的 bash              |
| gitleaks                    | 强烈建议 | secret-scan **响亮告警放行** | setup 自动装 / `winget install Gitleaks.Gitleaks`   |
| google-java-format          | 按需     | Java 格式化跳过（交 spotless）| 各自包管理器 / 手动下载 jar                         |
| ktlint                      | 按需     | Kotlin 格式化跳过（交插件）  | `scoop install ktlint` / `brew install ktlint`      |

> 注意：commit-title 已改为**纯 shell**，**不再需要 commitlint / Node**。

### 2.4 钩子与检查总览

| 钩子        | 检查                                       | 档位                         |
| ----------- | ------------------------------------------ | ---------------------------- |
| pre-commit  | gitleaks 秘密扫描                          | **阻断**（未装→告警放行）    |
| pre-commit  | 合并冲突标记 `<<<<<<<`                     | **阻断**                     |
| pre-commit  | 大文件（默认 >2MB）                        | **阻断**                     |
| pre-commit  | 私钥/凭据文件（`*.pem/.key/.jks/.env` 等） | **阻断**                     |
| pre-commit  | 禁止直接提交 `main`/`master`               | **阻断**（初始提交豁免）     |
| pre-commit  | Java/Kotlin 格式化                         | 自动修（缺工具→跳过）        |
| pre-commit  | Gradle/Maven 依赖改动提醒                  | 告警                         |
| pre-commit  | 栈叠加 `stacks/<栈>/pre-commit.d/*`        | 按需（默认空）               |
| commit-msg  | 标题规范（Conventional Commits，纯 shell） | **阻断**（merge/revert 放行）|
| commit-msg  | **强制 Signed-off-by** + 生成 AI trailer   | **阻断**(signoff) / 柔性(AI) |
| post-commit | 异步 AI 度量埋点                           | 不阻塞                       |
| pre-push    | 栈叠加 `stacks/<栈>/pre-push.d/*`          | 按需（默认空，测试交 CI）    |

> `pre-commit` 在 **merge / rebase** 期间自动跳过，避免解决冲突时被反复打扰。

### 2.5 通用层 + 栈叠加：怎么加栈专属规则

- **通用层 `common/`**：全栈通用、永远跑。格式化按文件扩展名分流，天然支持多语言混合仓。
- **栈叠加 `stacks/<栈>/`**：按 `lib/detect.sh` 侦测结果自动叠加，默认空。往对应目录放 `*.sh` 即被拾取：

  ```
  stacks/android/pre-commit.d/detekt.sh    # 提交前叠加（快检查）
  stacks/java/pre-push.d/compile.sh        # 推送前叠加（慢检查）
  ```

  脚本非 0 退出即阻断（受 `QG_WARN_ONLY` 影响），可复用共享库：

  ```sh
  . "$(dirname "$0")/../../../lib/_lib.sh"
  some_check || qg_fail "detekt" "Kotlin 静态检查未通过"
  ```

### 2.6 AI 溯源：两段式上报（覆盖率 100%）

**方式 A — 工具自动信号（优先）**：AI 工具 / CI 设环境变量，提交自动生成 trailer：

```bash
export QG_AI_DEGREE=co-authored                  # assisted | co-authored | generated
export QG_AI_TOOL="claude-code (claude-opus-4-8)"
```

**方式 B — 提交时自报（兜底）**：未给自动信号时，提交编辑器里预置三档注释，**取消注释你选的一项**（去掉行首 `# `）：

```
# ── AI 参与度（取消注释你选的一项，默认 none）──────────
QG-AI: co-authored   # ← 选中
```

| Trailer           | 含义                   | 力度                                          |
| ----------------- | ---------------------- | --------------------------------------------- |
| `Assisted-by:`    | AI 轻度协助（≤33%）    | 柔性·鼓励                                     |
| `Co-authored-by:` | AI 实质贡献（35–67%）  | 柔性·鼓励（带 `<email>`，平台可识别为协作者） |
| `Generated-by:`   | 主要由 AI 生成（67%+） | 柔性·鼓励                                     |
| `Signed-off-by:`  | **人类对正确性负责**   | **硬性·阻断**（自动补、零负担）               |

**两条铁律**：准确优先（默认 none、不逼人乱填）；问责兜底（每个提交必有 Signed-off-by）。

度量落在 `.git/ai-metrics.log`（`SHA \t AI档位 \t Signed-off-by \t 增删行`），在 `.git/` 内不进版本控制。

### 2.7 配置项（环境变量）

| 变量                          | 默认               | 作用                                                            |
| ----------------------------- | ------------------ | --------------------------------------------------------------- |
| `QG_WARN_ONLY`                | `0`                | 设 `1` → **试点模式**：阻断级降级为「告警但放行」（推广前两周） |
| `QG_PROFILE`                  | —                  | 强制技术栈（`android`/`java`），覆盖自动侦测                    |
| `QG_AI_DEGREE` / `QG_AI_TOOL` | —                  | AI 自动信号来源                                                 |
| `QG_AI_EMAIL`                 | `ai@noreply.local` | AI trailer 邮箱，令 `Co-authored-by` 被平台识别                 |
| `QG_MAX_FILE_KB`              | `2048`             | 大文件阈值（KB）                                                |
| `QG_ALLOW_COMMIT_TO_MAIN`     | `0`                | 设 `1` → 临时允许直接提交受保护分支                             |
| `QG_PROTECTED_BRANCHES`       | `main master`      | 自定义受保护分支                                                |
| `QG_SKIP_TOOL_INSTALL`        | `0`                | 设 `1` → setup 跳过 gitleaks 自动安装                           |
| `QG_DIFF_RANGE`               | —                  | 未来 CI：把检查对象从暂存区切到 diff range                      |

### 2.8 常见场景速查

| 场景                      | 操作                                                            |
| ------------------------- | --------------------------------------------------------------- |
| 新仓库首次提交到 main     | 直接提交即可（**初始提交自动豁免**）                            |
| 已有提交后需直接改 main   | `QG_ALLOW_COMMIT_TO_MAIN=1 git commit ...`，或走特性分支        |
| 提交大文件（如模型/数据） | 改用 `git lfs track`，或 `QG_MAX_FILE_KB=<更大> git commit ...` |
| gitleaks 误报             | 在 `.gitleaksignore` 写入指纹豁免                               |
| 私钥误报（实为模板）      | 重命名为 `*.example` / `*.sample` / `*.template`                |
| 试点期不想被挡            | `export QG_WARN_ONLY=1`                                         |
| 标题被拦                  | 用 `type(scope): 简述`，如 `feat(pig): 新增育肥统计`            |
| 侦测栈不准                | 仓库根建 `.githooks.profile`（首行 `android`/`java`），或 `QG_PROFILE=java` |
| 想加本地测试把关          | 往 `stacks/<栈>/pre-push.d/` 放脚本（默认交 CI）                |
| 紧急绕过全部钩子          | `git commit --no-verify`（应极少用；CI 仍会兜底）               |

### 2.9 故障排查

| 现象                              | 原因 / 处理                                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `commit-msg` 报缺少 Signed-off-by | 未配置 git 身份 → `git config user.name/user.email`，或 `git commit -s`                                 |
| `sh: bad interpreter ^M`          | 脚本被改成 CRLF；`.gitattributes` 强制 `eol=lf`，`git add --renormalize .` 后重提交                     |
| 钩子完全不触发                    | 查 `core.hooksPath`：`git config --get core.hooksPath` 应为 `.githooks`；被 Husky 占用则 `--unset` 后重跑 setup |
| 提交没触发任何检查                | 该 clone 未跑过 setup（`core.hooksPath` 未设）→ `sh scripts/setup.sh`                                   |
| Java/Kotlin 没被格式化            | 未装 google-java-format / ktlint（属预期，交构建期 spotless/ktlint 插件），或装上后重试                 |

### 2.10 未来接 CI（GitLab / GitHub Actions）

检查逻辑已与 staged / diff-range 解耦。CI 中对 MR/PR diff 设：

```bash
export QG_DIFF_RANGE="$CI_MERGE_REQUEST_DIFF_BASE_SHA...HEAD"   # GitLab
# 或 GitHub： export QG_DIFF_RANGE="origin/${{ github.base_ref }}...HEAD"
sh .githooks/common/secret-scan.sh
sh .githooks/common/no-large-files.sh
# … 同一批 .githooks/common/*.sh 直接复用，零重写
```

---

## 三、目录结构

```
scripts/setup.{sh,ps1}             # 一键激活（core.hooksPath + gitleaks 引导 + 自检）
Makefile                           # make setup → sh scripts/setup.sh
tests/run-tests.sh                 # 回归测试（临时仓库真实提交断言，49 项场景）
.githooks/                         # 整个工具集，cp 进任何仓库即用
  pre-commit                       # 编排：通用层 + 栈叠加（merge/rebase 跳过）
  pre-push                         # 编排：慢检查下沉处（默认交 CI）
  prepare-commit-msg               # AI 三档模板 + 读自动信号
  commit-msg                       # 编排：标题规范 + Signed-off-by + AI trailer
  post-commit                      # 异步度量埋点
  lib/
    _lib.sh                        # 共享库：warn-only / 文件清单解耦 / 日志
    detect.sh                      # 侦测技术栈：android | java
  common/                          # 全栈通用检查（永远跑）
    secret-scan.sh                 # gitleaks
    no-conflict-markers.sh         # 冲突标记
    no-large-files.sh              # 大文件阈值
    block-sensitive-files.sh       # 私钥/凭据
    protect-branch.sh              # 禁 main（初始提交豁免）
    format.sh                      # Java/Kotlin 格式化
    deps-consistency.sh            # Gradle/Maven 依赖告警
    commit-title.sh                # Conventional Commits（纯 shell 正则）
    signoff-trailer.sh             # Signed-off-by + AI trailer 生成
  stacks/                          # 栈专属叠加（默认空，按需后补）
    README.md
    android/{pre-commit.d,pre-push.d}/
    java/{pre-commit.d,pre-push.d}/
```
