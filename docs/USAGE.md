# 本地 Git Hooks —— 项目说明与使用配置指南

> 配套精简版见仓库根 [`README.md`](../README.md)；本手册补充故障排查、场景速查等展开内容。

---

## 一、项目说明

### 1.1 这是什么

一套**纯本地、基于 lefthook 编排**的 git 钩子系统。提交/推送时自动跑通用门禁（秘密扫描、格式化、提交规范、依赖检查等）并写入 **AI 溯源 trailer**，沉淀"谁 / AI 参与了多少 / 谁担责"的度量。

**设计定位**：本地钩子是**反馈 / 助手层**，不是强制门禁——

- 阻断档（exit≠0）只放**确定性、近零误报**的检查；
- 其余**告警**或**自动修**；
- 检查逻辑与"staged vs diff range"解耦，未来接 GitLab CI 几小时即可复用，零重写。

### 1.2 架构（四层 + 触发链路）

| 层         | 角色                                                  | 产物                                                    |
| ---------- | ----------------------------------------------------- | ------------------------------------------------------- |
| 框架层     | lefthook，把配置翻译成真实 git hook、自动安装、跨平台 | `lefthook.yml`                                          |
| 现成工具层 | 被钩子调用的通用门禁                                  | gitleaks / commitlint / prettier 等                     |
| 自研脚本层 | 组织特有的 AI 溯源（唯一要自己写的部分）              | `.githooks/{prepare-commit-msg,commit-msg,post-commit}` |
| 编排约定   | 哪个检查挂哪个钩子、阻断 / 告警、试点节奏             | `lefthook.yml` + `.githooks/checks/_lib.sh`             |

```
git commit / git push
   └─ lefthook 拦截对应钩子
      ├─ pre-commit          secret-scan / merge-conflict / large-file / private-key
      │                      / no-commit-to-main / format / deps-check   (merge/rebase 时跳过)
      ├─ prepare-commit-msg  预置 AI 三档选项 + 读工具自动信号
      ├─ commit-msg          强制 Signed-off-by（阻断）+ 生成 AI trailer + commitlint 标题规范
      ├─ post-commit         异步写 AI 使用度量（.git/ai-metrics.log）
      └─ pre-push            affected-tests（慢检查下沉于此）
```

### 1.3 技术选型

| 维度     | 选择                                                                                 |
| -------- | ------------------------------------------------------------------------------------ |
| 框架     | **lefthook**（独立二进制、并行、语言无关，适配 Java/Vue/TS/Kotlin/JS/Python 混合栈） |
| 秘密扫描 | **gitleaks**（`git --staged`，8.18+ 语法，旧版回退 `protect`）                       |
| 提交规范 | **commitlint** + config-conventional                                                 |
| 格式化   | 按扩展名分流：prettier / ruff(black) / ktlint / google-java-format                   |
| AI 信号  | 两段式：工具自动信号（环境变量）优先，提交时取消注释自报兜底                         |
| Trailer  | AI 三档（柔性·鼓励）+ `Signed-off-by`（硬性·阻断）                                   |

---

## 二、使用与配置指南

### 2.1 快速开始（三步）

```bash
git init                 # 若尚不是 git 仓库
npm i -D lefthook        # 装 lefthook（也可 winget/scoop/brew 装系统二进制）
make setup               # = lefthook install + 自动装 gitleaks + 权限 + 自检
```

> `npm i` 会触发 `prepare` 脚本自动 `lefthook install`；commitlint / prettier 作为 devDependencies 也一并装上。
> 非 npm 栈：`sh scripts/setup.sh`（Unix / git-bash）或 `powershell -ExecutionPolicy Bypass -File scripts\setup.ps1`（Windows）。

### 2.2 前置与可选依赖

| 工具                                   | 必需？   | 缺失时行为                   | 安装                                                         |
| -------------------------------------- | -------- | ---------------------------- | ------------------------------------------------------------ |
| lefthook                               | ✅ 必需  | setup 报错退出               | `npm i -D lefthook` / `winget install evilmartians.lefthook` |
| gitleaks                               | 强烈建议 | secret-scan **响亮告警放行** | setup 自动装 / `winget install Gitleaks.Gitleaks`            |
| commitlint                             | 建议     | 标题检查跳过                 | 随 `npm install`                                             |
| prettier                               | 建议     | 格式化跳过                   | 随 `npm install`                                             |
| ruff/black、ktlint、google-java-format | 按语言   | 对应语言格式化跳过           | 各自包管理器                                                 |

### 2.3 钩子与检查总览

| 钩子        | 检查                                       | 档位                         |
| ----------- | ------------------------------------------ | ---------------------------- |
| pre-commit  | gitleaks 秘密扫描                          | **阻断**（未装→告警放行）    |
| pre-commit  | 合并冲突标记 `<<<<<<<`                     | **阻断**                     |
| pre-commit  | 大文件（默认 >2MB）                        | **阻断**                     |
| pre-commit  | 私钥/凭据文件（`*.pem/.key/.p12/.env` 等） | **阻断**                     |
| pre-commit  | 禁止直接提交 `main`/`master`               | **阻断**（初始提交豁免）     |
| pre-commit  | 按语言格式化                               | 自动修                       |
| pre-commit  | lockfile 一致性 / 新增依赖                 | 告警                         |
| commit-msg  | **强制 Signed-off-by** + 生成 AI trailer   | **阻断**(signoff) / 柔性(AI) |
| commit-msg  | 标题规范（Conventional Commits）           | 阻断（未装→跳过）            |
| post-commit | 异步 AI 度量埋点                           | 不阻塞                       |
| pre-push    | 受影响测试 / 类型检查                      | **阻断**                     |

> `pre-commit` 在 **merge / rebase** 期间自动跳过，避免解决冲突时被反复打扰。

### 2.4 AI 溯源：两段式上报（覆盖率 100%）

**方式 A — 工具自动信号（优先）**：AI 工具 / CI 设环境变量，提交自动生成 trailer：

```bash
export QG_AI_DEGREE=co-authored                  # assisted | co-authored | generated
export QG_AI_TOOL="claude-code/2.1 (claude-opus-4-8)"
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

度量落在 `.git/ai-metrics.log`（`SHA \t AI档位 \t Signed-off-by \t 增删行`），在 `.git/` 内不进版本控制。可用于事后聚合 AI 使用度量，未来可替换为发埋点事件。

### 2.5 配置项（环境变量）

| 变量                          | 默认               | 作用                                                            |
| ----------------------------- | ------------------ | --------------------------------------------------------------- |
| `QG_WARN_ONLY`                | `0`                | 设 `1` → **试点模式**：阻断级降级为「告警但放行」（推广前两周） |
| `QG_AI_DEGREE` / `QG_AI_TOOL` | —                  | AI 自动信号来源                                                 |
| `QG_AI_EMAIL`                 | `ai@noreply.local` | AI trailer 邮箱，令 `Co-authored-by` 被平台识别                 |
| `QG_MAX_FILE_KB`              | `2048`             | 大文件阈值（KB）                                                |
| `QG_ALLOW_COMMIT_TO_MAIN`     | `0`                | 设 `1` → 临时允许直接提交受保护分支                             |
| `QG_PROTECTED_BRANCHES`       | `main master`      | 自定义受保护分支                                                |
| `QG_SKIP_TOOL_INSTALL`        | `0`                | 设 `1` → setup 跳过 gitleaks 自动安装                           |
| `QG_DIFF_RANGE`               | —                  | 未来 CI：把检查对象从暂存区切到 diff range                      |

### 2.6 常见场景速查

| 场景                      | 操作                                                            |
| ------------------------- | --------------------------------------------------------------- |
| 新仓库首次提交到 main     | 直接提交即可（**初始提交自动豁免**）                            |
| 已有提交后需直接改 main   | `QG_ALLOW_COMMIT_TO_MAIN=1 git commit ...`，或走特性分支        |
| 提交大文件（如模型/数据） | 改用 `git lfs track`，或 `QG_MAX_FILE_KB=<更大> git commit ...` |
| gitleaks 误报             | 在 `.gitleaksignore` 写入指纹豁免                               |
| 私钥误报（实为模板）      | 重命名为 `*.example` / `*.sample` / `*.template`                |
| 试点期不想被挡            | `export QG_WARN_ONLY=1`                                         |
| 标题被 commitlint 拒      | 用 `type(scope): 简述`，如 `feat(auth): 支持短信登录`           |
| 紧急绕过全部钩子          | `git commit --no-verify`（应极少用；CI 仍会兜底）               |

### 2.7 故障排查

| 现象                              | 原因 / 处理                                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `commit-msg` 报缺少 Signed-off-by | 未配置 git 身份 → `git config user.name/user.email`，或 `git commit -s`                                 |
| 自检显示 prettier/commitlint 未装 | 它们装在 `node_modules`，需先 `npm install`；脚本经 `npx` 调用本就能跑                                  |
| `sh: bad interpreter ^M`          | 脚本被改成 CRLF；`.gitattributes` 已强制 `eol=lf`，`git add --renormalize .`                            |
| 钩子完全不触发                    | 查 `core.hooksPath` 是否被 Husky 占用：`git config --get core.hooksPath`，必要时 `--unset` 后重跑 setup |
| `lefthook: command not found`     | 用 `npx --no-install lefthook ...` 或装系统二进制                                                       |

### 2.8 未来接 CI（GitLab）

检查逻辑已与 staged / diff-range 解耦。CI 中对 MR diff 设：

```bash
export QG_DIFF_RANGE="$CI_MERGE_REQUEST_DIFF_BASE_SHA...HEAD"
sh .githooks/checks/secret-scan.sh
sh .githooks/checks/no-large-files.sh
# … 同一批 .githooks/checks/*.sh 直接复用，零重写
```

---

## 三、目录结构

```
lefthook.yml                       # 编排：哪个检查挂哪个钩子、阻断/告警、merge/rebase skip
Makefile / scripts/setup.{sh,ps1}  # 一键安装（lefthook install + gitleaks 引导 + 自检）
commitlint.config.js               # 标题规范（Conventional Commits）
.prettierignore                    # 锁文件等不被格式化
.githooks/
  prepare-commit-msg               # AI 三档模板 + 读自动信号
  commit-msg                       # Signed-off-by 阻断 + 生成 AI trailer
  post-commit                      # 异步度量埋点
  checks/
    _lib.sh                        # 共享库：warn-only / 文件清单解耦 / 日志
    secret-scan.sh                 # gitleaks
    no-conflict-markers.sh         # 冲突标记
    no-large-files.sh              # 大文件阈值
    block-sensitive-files.sh       # 私钥/凭据
    protect-branch.sh              # 禁 main（初始提交豁免）
    format.sh                      # 按语言格式化
    deps-consistency.sh            # lockfile/依赖告警
    affected-tests.sh              # pre-push 测试/类型检查
    commit-title.sh                # commitlint 包装
```
