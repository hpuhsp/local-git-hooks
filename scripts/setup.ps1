# scripts/setup.ps1 — Windows 下安装并激活本地 git hooks（规格 §2/§6.1）
# 用法（仓库根目录）：  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
$ErrorActionPreference = 'Stop'

git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "当前目录不是 git 仓库。请先：git init"; exit 1 }

$existing = (git config --get core.hooksPath)
if ($existing) {
  Write-Warning "core.hooksPath = '$existing'，可能与 lefthook 冲突（如 Husky）。请先 git config --unset core.hooksPath 或协调后再装。"
}

if (Get-Command lefthook -ErrorAction SilentlyContinue) {
  lefthook install
} elseif (Get-Command npx -ErrorAction SilentlyContinue) {
  npx --no-install lefthook install
} else {
  Write-Error "未找到 lefthook。请安装：npm i -D lefthook（随后 npm install），或 scoop install lefthook / winget install evilmartians.lefthook"
  exit 1
}

Write-Host "✅ hooks 已激活。commitlint 经 npx 调用，需先 npm install。"
Write-Host "ℹ️  可选格式化/扫描工具（gitleaks/prettier/ruff 等）缺失时对应检查会跳过或告警，不阻断。"
