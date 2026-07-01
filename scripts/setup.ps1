# scripts/setup.ps1 — Windows 下安装并激活本地 git hooks（纯 core.hooksPath 文件夹工具集）
# 用法（仓库根目录）：  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
$ErrorActionPreference = 'Stop'

git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "当前目录不是 git 仓库。请先：git init"; exit 1 }
Set-Location (git rev-parse --show-toplevel)

$existing = (git config --get core.hooksPath)
if ($existing -and $existing -ne '.githooks') {
  Write-Warning "当前 core.hooksPath = '$existing'（如 Husky 的 .husky）。继续将改为 .githooks；如需并存请先协调。"
}

# 激活：指向版本控制内的 .githooks（无需任何二进制 / Node）
git config core.hooksPath .githooks
Write-Host "▶ 已设置 core.hooksPath = .githooks"

# gitleaks 引导安装（缺失时 best-effort 自动装，失败不阻断）
if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue) -and $env:QG_SKIP_TOOL_INSTALL -ne '1') {
  Write-Host "▶ 未发现 gitleaks，尝试自动安装（设 QG_SKIP_TOOL_INSTALL=1 可跳过）..."
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try { winget install --id Gitleaks.Gitleaks -e --accept-source-agreements --accept-package-agreements --disable-interactivity } catch {}
  } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    try { scoop install gitleaks } catch {}
  } else {
    Write-Host "   未找到 winget/scoop，请手动安装：https://github.com/gitleaks/gitleaks/releases"
  }
}

Write-Host ""
Write-Host "✅ hooks 已激活（无需 Node / lefthook）。可选工具（google-java-format / ktlint）缺失时对应格式化会跳过，不阻断。"
