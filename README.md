# 本地 Git Hooks（文件夹工具集 + AI 溯源）

一套**纯 `core.hooksPath` 的 git 钩子工具集**：一个 `.githooks/` 文件夹 + 一行 `git config` 即激活，提交/推送时跑通用门禁（秘密扫描、大文件、冲突标记、分支保护、格式化、提交规范）并写入 **AI 溯源 trailer**。
**零依赖**——不需要 Node / npm / lefthook，`cp -r .githooks/` 进任何仓库即用。

> 适用：**Android（Java+Kotlin+Gradle）+ Java 后端（Maven/Gradle）**。前端 Vue/uni-app 请用 Husky。
> 设计原则：阻断档近零误报，其余告警或自动修；检查与「staged vs diff range」解耦，未来接 CI 零重写。

## 一、安装

前置：目标目录是 git 仓库（`git init`）。

**A. 一键接入到任意项目（推荐）**——在**目标仓库根目录**跑一行，自动拉取工具集、落地 `.githooks/`、合并 `.gitattributes` 的 LF 规则、激活并引导装 gitleaks：

```bash
curl -fsSL https://raw.githubusercontent.com/hpuhsp/local-git-hooks/master/install.sh | sh
```

> 幂等：重复运行即更新（保留你自加的 `stacks/*.d/` 脚本）。卸载：`sh install.sh --uninstall`。离线：`QG_LOCAL_SRC=/path/to/kit sh install.sh`。

**B. 已在本仓库内**——直接激活：

```bash
sh scripts/setup.sh                                           # Linux / macOS / git-bash
# 或   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # Windows 原生
```

`setup` 会：检测 `core.hooksPath` 冲突（避免覆盖 Husky） → `git config core.hooksPath .githooks` → 赋脚本可执行权限 → **缺失时 best-effort 自动装 gitleaks**（winget/scoop/brew，`QG_SKIP_TOOL_INSTALL=1` 可跳过） → 自检可选工具。

**接入只落两样东西**：`.githooks/`（工具集目录）+ `.gitattributes` 里两行 LF 规则（防 Windows CRLF 破坏 shebang）。激活状态写在本地 `.git/config`（不入库），故每个 clone 需各自跑一次 `install.sh`/`setup.sh`。

gitleaks 也可手动装：`winget install Gitleaks.Gitleaks`（Windows）/ `brew install gitleaks`（macOS）/ `scoop install gitleaks`。

可选格式化工具（缺失时对应格式化**自动跳过**，不阻断）：`google-java-format`、`ktlint`（也可完全交给构建期 spotless / ktlint 插件）。

> 受保护分支（`main`/`master`）的**初始提交**（空仓库、无父提交）自动放行。

## 二、各钩子做什么

| 钩子               | 检查                                                | 档位                         |
| ------------------ | --------------------------------------------------- | ---------------------------- |
| pre-commit         | gitleaks 秘密扫描                                   | **阻断**（未装则告警放行）   |
| pre-commit         | 合并冲突标记 `<<<<<<<`                              | **阻断**                     |
| pre-commit         | 大文件（默认 >2MB，`QG_MAX_FILE_KB` 可调）          | **阻断**                     |
| pre-commit         | 私钥/凭据文件（`*.pem/.key/.jks/.keystore/.env` 等）| **阻断**                     |
| pre-commit         | 禁止直接提交 `main`/`master`                        | **阻断**                     |
| pre-commit         | Java/Kotlin 格式化（google-java-format / ktlint）   | 自动修（缺工具则跳过）       |
| pre-commit         | Gradle/Maven 依赖改动提醒                           | 告警                         |
| pre-commit         | **栈叠加**：`stacks/<android\|java>/pre-commit.d/`  | 按需（默认空）               |
| prepare-commit-msg | 预置 AI 三档选项 + 读工具自动信号                   | —                            |
| commit-msg         | 标题规范（Conventional Commits，**纯 shell**）      | **阻断**（merge/revert 放行）|
| commit-msg         | **强制 `Signed-off-by`** + 生成 AI trailer          | **阻断**(signoff) / 柔性(AI) |
| post-commit        | 异步 AI 使用度量埋点                                | 不阻塞                       |
| pre-push           | **栈叠加**：`stacks/<...>/pre-push.d/`（默认交 CI） | 按需（默认空）               |

> `pre-commit` 在 **merge / rebase** 期间自动跳过，避免解决冲突时被反复打扰。
> 慢检查（测试/编译）默认**不在本地跑**，交给 CI；需要本地把关就往 `stacks/<栈>/pre-push.d/` 放脚本。

## 三、通用层 + 栈叠加（怎么支持多栈）

两个栈的差异其实很小（主要是「用哪个格式化器」），所以设计成 **一层厚通用 + 一层薄叠加**：

- **`common/`**：全栈通用，永远跑（占 90%）。格式化按**文件扩展名**分流（`.java`→google-java-format，`.kt`→ktlint），天然支持混合仓。
- **`stacks/<栈>/`**：栈专属额外规则，按 `lib/detect.sh` 侦测结果**自动叠加**，默认空、按需后补（如 android/detekt、java/checkstyle）。
- **侦测为主、档位兜底**：`build.gradle` 含 `com.android.*`→`android`；有 `pom.xml`/`build.gradle`→`java`。侦测不准时，仓库根建 `.githooks.profile`（首行写 `android`/`java`）或临时 `QG_PROFILE=java`。

## 四、AI 参与度怎么报（两段式，覆盖率 100%）

1. **工具自动信号（优先）**：设环境变量，提交时自动生成 trailer：

   ```bash
   export QG_AI_DEGREE=co-authored                 # assisted | co-authored | generated
   export QG_AI_TOOL="claude-code (claude-opus-4-8)"
   ```

2. **提交时自报（兜底）**：未给自动信号时，编辑器里预置三档注释，**取消注释你选的一项**即可：

   ```
   # ── AI 参与度（取消注释你选的一项，默认 none）──────────
   QG-AI: co-authored   # ← 去掉行首 "# " 即选中
   ```

| Trailer           | 含义                     | 力度                                |
| ----------------- | ------------------------ | ----------------------------------- |
| `Assisted-by:`    | AI 轻度协助（约 ≤33%）   | 柔性·鼓励                           |
| `Co-authored-by:` | AI 实质贡献（约 35–67%） | 柔性·鼓励（带 `<email>` 平台可识别）|
| `Generated-by:`   | 主要由 AI 生成（67%+）   | 柔性·鼓励                           |
| `Signed-off-by:`  | **人类对正确性负责**     | **硬性·阻断**（自动补，几乎零负担） |

**两条铁律**：准确优先（默认 none、不逼人乱填，保住度量真实性）；问责兜底（每个提交必有 `Signed-off-by`）。

度量落在 `.git/ai-metrics.log`（`SHA \t AI档位 \t Signed-off-by \t 增删行`），位于 `.git/` 内，不进版本控制。

## 五、环境变量开关

| 变量                          | 作用                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `QG_WARN_ONLY=1`              | **试点模式**：阻断级检查降级为「告警但放行」（全员推广前两周）                 |
| `QG_PROFILE`                  | 强制技术栈（`android`/`java`），覆盖自动侦测                                    |
| `QG_AI_DEGREE` / `QG_AI_TOOL` | AI 自动信号来源                                                                |
| `QG_AI_EMAIL`                 | AI trailer 的邮箱（默认 `ai@noreply.local`）；令 `Co-authored-by` 可被平台识别 |
| `QG_MAX_FILE_KB`              | 大文件阈值，单位 KB（默认 2048）                                               |
| `QG_ALLOW_COMMIT_TO_MAIN=1`   | 临时允许直接提交受保护分支                                                     |
| `QG_PROTECTED_BRANCHES`       | 自定义受保护分支（默认 `main master`）                                         |
| `QG_SKIP_TOOL_INSTALL=1`      | `setup` 时跳过 gitleaks 的 best-effort 自动安装                                |
| `QG_DIFF_RANGE`               | 未来 CI 复用：把检查对象从暂存区切到 diff range                               |

## 六、目录结构

```
scripts/setup.{sh,ps1}           # 一键激活（core.hooksPath + gitleaks 引导 + 自检）
Makefile                         # make setup → sh scripts/setup.sh
tests/run-tests.sh               # 回归测试：sh tests/run-tests.sh（49 项场景断言）
.githooks/                       # 整个工具集，cp 进任何仓库即用
  pre-commit                     # 编排：通用层 + 栈叠加（merge/rebase 跳过）
  pre-push                       # 编排：慢检查下沉处（默认交 CI）
  prepare-commit-msg             # AI 三档模板 + 读自动信号
  commit-msg                     # 编排：标题规范 + Signed-off-by + AI trailer
  post-commit                    # 异步度量埋点
  lib/
    _lib.sh                      # 共享库：warn-only / 文件清单解耦 / 日志
    detect.sh                    # 侦测技术栈：android | java
  common/                        # 全栈通用检查（永远跑）
    secret-scan.sh               # gitleaks
    no-conflict-markers.sh       # 冲突标记
    no-large-files.sh            # 大文件阈值
    block-sensitive-files.sh     # 私钥/凭据
    protect-branch.sh            # 禁 main（初始提交豁免）
    format.sh                    # Java/Kotlin 格式化
    deps-consistency.sh          # Gradle/Maven 依赖告警
    commit-title.sh              # Conventional Commits（纯 shell 正则）
    signoff-trailer.sh           # Signed-off-by + AI trailer 生成
  stacks/                        # 栈专属叠加（默认空，按需后补）
    android/{pre-commit.d,pre-push.d}/
    java/{pre-commit.d,pre-push.d}/
```

## 七、未来接 CI

检查逻辑已与「staged vs diff range」解耦：CI 里对 MR/PR diff 设 `QG_DIFF_RANGE="$BASE_SHA...HEAD"`，同一批 `.githooks/common/*.sh` 直接复用，零重写。详见 [`docs/USAGE.md`](docs/USAGE.md)。
