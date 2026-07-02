# Local Git Hooks (Folder Toolkit + AI Provenance)

**English** | [简体中文](README.zh-CN.md)

A pure **`core.hooksPath` git-hooks toolkit**: one `.githooks/` folder + a single `git config` line to activate. On commit/push it runs common gates (secret scan, large files, conflict markers, branch protection, formatting, commit conventions) and writes **AI-provenance trailers**.
**Zero dependencies** — no Node / npm / lefthook; `cp -r .githooks/` into any repo and go.

> Targets: **Android (Java+Kotlin+Gradle) + Java backend (Maven/Gradle)**. For Vue/uni-app frontends, use Husky.
> Design principle: near-zero false positives on blocking checks, everything else warns or auto-fixes; checks are decoupled from "staged vs diff range", so wiring up CI later needs zero rewrite.

## 1. Install

Prerequisite: the target directory is a git repo (`git init`).

**A. One-line onboarding into any project (recommended)** — run this in the **target repo root**; it fetches the toolkit, drops in `.githooks/`, merges the LF rules into `.gitattributes`, activates, and bootstraps gitleaks:

```bash
curl -fsSL https://raw.githubusercontent.com/hpuhsp/local-git-hooks/master/install.sh | sh
```

> Idempotent: re-run to update (keeps your own `stacks/*.d/` scripts). Uninstall: `sh install.sh --uninstall`. Offline: `QG_LOCAL_SRC=/path/to/kit sh install.sh`.

**B. Already inside this repo** — activate directly:

```bash
sh scripts/setup.sh                                           # Linux / macOS / git-bash
# or   powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # native Windows
```

`setup` will: detect a `core.hooksPath` conflict (avoid overwriting Husky) → `git config core.hooksPath .githooks` → make scripts executable → **best-effort auto-install gitleaks when missing** (winget/scoop/brew; skip with `QG_SKIP_TOOL_INSTALL=1`) → self-check optional tools.

**Onboarding adds only two things**: the `.githooks/` folder + two LF-rule lines in `.gitattributes` (prevents Windows CRLF from breaking the shebang). Activation lives in local `.git/config` (not committed), so each clone runs `install.sh`/`setup.sh` once.

gitleaks can also be installed manually: `winget install Gitleaks.Gitleaks` (Windows) / `brew install gitleaks` (macOS) / `scoop install gitleaks`.

Optional formatters (when missing, the corresponding formatting **auto-skips**, never blocks): `google-java-format`, `ktlint` (or leave it entirely to build-time spotless / ktlint plugins).

> The **initial commit** on a protected branch (`main`/`master`) — empty repo, no parent — is allowed automatically.

**Staying up to date**: updates are manual by design — re-run the one-liner above (idempotent, keeps your `stacks/*.d/`). The toolkit only **notifies** you (at most once a day, via non-blocking `post-commit`) when a newer version exists; it **never self-modifies** — auto-executing remote code as hooks would be a supply-chain risk. Silence the notice with `QG_NO_UPDATE_CHECK=1`.

## 2. What each hook does

| Hook               | Check                                                     | Level                          |
| ------------------ | -------------------------------------------------------- | ------------------------------ |
| pre-commit         | gitleaks secret scan                                     | **Block** (warn & pass if absent) |
| pre-commit         | merge conflict markers `<<<<<<<`                         | **Block**                      |
| pre-commit         | large files (>2MB default, tunable via `QG_MAX_FILE_KB`) | **Block**                      |
| pre-commit         | private-key/credential files (`*.pem/.key/.jks/.keystore/.env` …) | **Block**             |
| pre-commit         | direct commits to `main`/`master`                        | **Block**                      |
| pre-commit         | Java/Kotlin formatting (google-java-format / ktlint)     | Auto-fix (skip if tool absent) |
| pre-commit         | Gradle/Maven dependency-change reminder                  | Warn                           |
| pre-commit         | **stack overlay**: `stacks/<android\|java>/pre-commit.d/`| Optional (empty by default)    |
| prepare-commit-msg | preset 3-level AI options + read tool auto-signal        | —                              |
| commit-msg         | title convention + **content quality** (format + reject lazy subjects, pure shell) | **Block** (merge/revert pass) |
| commit-msg         | **enforce `Signed-off-by`** + generate AI trailer        | **Block** (signoff) / soft (AI)|
| post-commit        | async AI-usage metrics                                   | Non-blocking                   |
| pre-push           | **stack overlay**: `stacks/<…>/pre-push.d/` (tests to CI by default) | Optional (empty by default) |

> `pre-commit` auto-skips during **merge / rebase**, so you aren't nagged while resolving conflicts.
> Slow checks (test/compile) don't run locally by default — they go to CI. To gate locally, drop scripts into `stacks/<stack>/pre-push.d/`.

## 3. Common layer + stack overlays (how multi-stack works)

The two stacks differ very little (mainly "which formatter"), so it's designed as **one thick common layer + one thin overlay**:

- **`common/`**: universal, always runs (~90%). Formatting dispatches by **file extension** (`.java`→google-java-format, `.kt`→ktlint), so mixed repos work naturally.
- **`stacks/<stack>/`**: stack-specific extra rules, **auto-layered** per `lib/detect.sh`; empty by default, add as needed (e.g. android/detekt, java/checkstyle).
- **Detection first, profile as fallback**: `build.gradle` containing `com.android.*` → `android`; `pom.xml`/`build.gradle` → `java`. If detection is wrong, create `.githooks.profile` at the repo root (first line `android`/`java`) or set `QG_PROFILE=java`.

## 4. Reporting AI involvement (two-stage, 100% coverage)

1. **Tool auto-signal (preferred)**: set env vars; the trailer is generated on commit:

   ```bash
   export QG_AI_DEGREE=co-authored                 # assisted | co-authored | generated
   export QG_AI_TOOL="claude-code (claude-opus-4-8)"
   ```

2. **Self-report at commit time (fallback)**: when there's no auto-signal, the editor pre-fills three commented options — **uncomment the one you pick**:

   ```
   # ── AI involvement (uncomment the one you pick, default none) ──
   QG-AI: co-authored   # ← remove the leading "# " to select
   ```

| Trailer           | Meaning                              | Force                                          |
| ----------------- | ------------------------------------ | ---------------------------------------------- |
| `Assisted-by:`    | light AI help (~≤33%)                | soft · encouraged                              |
| `Co-authored-by:` | substantial AI contribution (~35–67%)| soft · encouraged (with `<email>`, recognized by platforms) |
| `Generated-by:`   | mostly AI-generated (67%+)           | soft · encouraged                              |
| `Signed-off-by:`  | **human owns correctness**           | **hard · blocking** (auto-added, near-zero burden) |

**Two iron rules**: accuracy first (default none, no forced filling, keep metrics honest); accountability backstop (every commit has `Signed-off-by`).

Metrics land in `.git/ai-metrics.log` (`SHA \t AI-level \t Signed-off-by \t insertions/deletions`), inside `.git/`, not version-controlled.

## 5. Environment toggles

| Variable                      | Effect                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `QG_WARN_ONLY=1`              | **Pilot mode**: blocking checks downgrade to "warn but pass" (first two weeks of rollout) |
| `QG_TITLE_QUALITY=0`          | Disable the title "content quality" layer, keep only the Conventional Commits format check |
| `QG_PROFILE`                  | Force the stack (`android`/`java`), overriding auto-detection                   |
| `QG_AI_DEGREE` / `QG_AI_TOOL` | AI auto-signal source                                                          |
| `QG_AI_EMAIL`                 | Email for the AI trailer (default `ai@noreply.local`); makes `Co-authored-by` platform-recognizable |
| `QG_MAX_FILE_KB`              | Large-file threshold in KB (default 2048)                                      |
| `QG_ALLOW_COMMIT_TO_MAIN=1`   | Temporarily allow direct commits to protected branches                         |
| `QG_PROTECTED_BRANCHES`       | Custom protected branches (default `main master`)                              |
| `QG_SKIP_TOOL_INSTALL=1`      | Skip the gitleaks best-effort auto-install during `setup`                      |
| `QG_NO_UPDATE_CHECK=1`        | Disable the throttled "new version available" notice (notify-only, ≤ once/day)  |
| `QG_DIFF_RANGE`               | Future CI reuse: switch the check target from the staged area to a diff range   |

## 6. Directory layout

```
scripts/setup.{sh,ps1}           # one-line activation (core.hooksPath + gitleaks bootstrap + self-check)
Makefile                         # make setup → sh scripts/setup.sh
tests/run-tests.sh               # regression suite: sh tests/run-tests.sh (59 scenario assertions)
.githooks/                       # the whole toolkit, cp into any repo
  VERSION                        # version stamp (drives the update notice)
  pre-commit                     # orchestration: common layer + stack overlay (skips merge/rebase)
  pre-push                       # orchestration: home for slow checks (to CI by default)
  prepare-commit-msg             # AI 3-level template + read auto-signal
  commit-msg                     # orchestration: title convention + Signed-off-by + AI trailer
  post-commit                    # async metrics + throttled update notice
  lib/
    _lib.sh                      # shared lib: warn-only / file-list decoupling / logging
    detect.sh                    # stack detection: android | java
    update-check.sh              # throttled "new version available" notice (notify-only)
  common/                        # universal checks (always run)
    secret-scan.sh               # gitleaks
    no-conflict-markers.sh       # conflict markers
    no-large-files.sh            # large-file threshold
    block-sensitive-files.sh     # private keys / credentials
    protect-branch.sh            # block main (initial commit exempt)
    format.sh                    # Java/Kotlin formatting
    deps-consistency.sh          # Gradle/Maven dependency warning
    commit-title.sh              # title convention + content quality (pure shell)
    signoff-trailer.sh           # Signed-off-by + AI trailer generation
  stacks/                        # stack-specific overlays (empty by default, add as needed)
    android/{pre-commit.d,pre-push.d}/
    java/{pre-commit.d,pre-push.d}/
```

## 7. Wiring up CI later

Checks are decoupled from "staged vs diff range": in CI, set `QG_DIFF_RANGE="$BASE_SHA...HEAD"` for the MR/PR diff and reuse the same `.githooks/common/*.sh` — zero rewrite. See the full guide in [`docs/USAGE.md`](docs/USAGE.md) (Chinese).
