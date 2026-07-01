# 栈叠加层（stacks/）

按 `lib/detect.sh` 侦测到的技术栈，自动叠加运行对应目录下的脚本。**默认为空**——通用层已覆盖 90% 需求，这里只放栈专属的额外规则，按需后补。

## 约定

```
stacks/<stack>/pre-commit.d/*.sh   # 提交前叠加（快检查）
stacks/<stack>/pre-push.d/*.sh     # 推送前叠加（慢检查；默认交 CI，故通常留空）
```

- `<stack>` 目前支持：`android`、`java`。
- dispatcher 会 `sh` 执行目录下所有 `*.sh`，**非 0 退出即阻断**（受 `QG_WARN_ONLY` 影响）。
- 脚本可 `. "$(dirname "$0")/../../../lib/_lib.sh"` 复用 `qg_fail` / `qg_warn` 等助手。

## 侦测与覆盖

- 自动侦测：`build.gradle` 含 `com.android.*` → `android`；有 `pom.xml`/`build.gradle` → `java`。
- 侦测不准时，在仓库根建 `.githooks.profile`（首行写 `android` 或 `java`），或临时 `QG_PROFILE=java`。

## 示例（可自行添加）

- `android/pre-commit.d/detekt.sh` — Kotlin 静态检查
- `java/pre-commit.d/checkstyle.sh` — Java 代码风格
- `java/pre-push.d/compile.sh` — `mvn -q compile` 快速编译把关
