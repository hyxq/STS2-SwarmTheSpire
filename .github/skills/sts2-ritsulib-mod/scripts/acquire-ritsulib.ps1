<#
.SYNOPSIS
    获取 RitsuLib 源码。

.DESCRIPTION
    从 GitHub 克隆或更新 RitsuLib 仓库到缓存目录。

.PARAMETER CacheDir
    缓存目录路径，默认为脚本所在目录的上级目录下的 cache/ritsulib

.PARAMETER ForceUpdate
    强制更新，即使已存在也执行 git pull

.EXAMPLE
    pwsh -File acquire-ritsulib.ps1
    pwsh -File acquire-ritsulib.ps1 -ForceUpdate
#>

param(
    [string]$CacheDir,
    [switch]$ForceUpdate
)

$ErrorActionPreference = "Stop"

$repoUrl = "https://github.com/BAKAOLC/STS2-RitsuLib.git"

# 默认缓存目录
if (-not $CacheDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $CacheDir = Join-Path (Split-Path -Parent $scriptDir) "cache" "ritsulib"
}

# 确保缓存目录存在
$cacheParent = Split-Path -Parent $CacheDir
if (-not (Test-Path $cacheParent)) {
    New-Item -ItemType Directory -Path $cacheParent -Force | Out-Null
}

if (Test-Path $CacheDir) {
    # 已存在，检查是否需要更新
    $gitDir = Join-Path $CacheDir ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Host "[WARN] 缓存目录存在但不是 Git 仓库，将重新克隆" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $CacheDir
    } else {
        if ($ForceUpdate) {
            Write-Host "[INFO] 强制更新 RitsuLib..." -ForegroundColor Cyan
            Push-Location $CacheDir
            try {
                git fetch --all
                git reset --hard origin/main
                Write-Host "[INFO] RitsuLib 更新完成" -ForegroundColor Green
            } finally {
                Pop-Location
            }
        } else {
            Write-Host "[INFO] RitsuLib 已存在于: $CacheDir" -ForegroundColor Green
            # 检查是否需要更新（超过 24 小时）
            $lastWrite = (Get-Item $CacheDir).LastWriteTime
            $age = (Get-Date) - $lastWrite
            if ($age.TotalHours -gt 24) {
                Write-Host "[INFO] 缓存超过 24 小时，执行安全更新..." -ForegroundColor Cyan
                Push-Location $CacheDir
                try {
                    git fetch origin
                    $behind = git rev-list HEAD..origin/main --count 2>$null
                    if ($behind -gt 0) {
                        git pull --ff-only
                        Write-Host "[INFO] 更新了 $behind 个提交" -ForegroundColor Green
                    } else {
                        Write-Host "[INFO] 已是最新版本" -ForegroundColor Green
                    }
                } finally {
                    Pop-Location
                }
            }
        }
        return
    }
}

# 克隆仓库
Write-Host "[INFO] 正在克隆 RitsuLib 仓库..." -ForegroundColor Cyan
git clone --depth 1 $repoUrl $CacheDir

if ($LASTEXITCODE -eq 0) {
    Write-Host "[INFO] RitsuLib 克隆完成: $CacheDir" -ForegroundColor Green
} else {
    Write-Error "[ERROR] 克隆 RitsuLib 失败"
    exit 1
}
