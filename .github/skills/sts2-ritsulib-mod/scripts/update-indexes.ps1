<#
.SYNOPSIS
    更新所有索引（跨平台）。

.DESCRIPTION
    更新缓存索引并重新构建内置索引。
    用户可运行此脚本来同步最新的 RitsuLib、教程和游戏源码。

.PARAMETER GameSourceRoot
    游戏源码目录（默认自动发现）

.PARAMETER SkipRitsuLib
    跳过更新 RitsuLib

.PARAMETER SkipTutorials
    跳过更新教程

.EXAMPLE
    pwsh -File update-indexes.ps1
    pwsh -File update-indexes.ps1 -SkipRitsuLib
#>

param(
    [string]$GameSourceRoot,
    [switch]$SkipRitsuLib,
    [switch]$SkipTutorials
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$cacheDir = Join-Path $skillRoot "cache"

# 脚本路径（使用 Join-Path 确保跨平台兼容）
$acquireRitsuScript = Join-Path $scriptDir "acquire-ritsulib.ps1"
$acquireTutorialsScript = Join-Path $scriptDir "acquire-tutorials.ps1"
$buildIndexScript = Join-Path $scriptDir "build-index.ps1"
$buildBuiltinScript = Join-Path $scriptDir "build-builtin-indexes.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  更新索引" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 显示平台信息
$platform = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }
Write-Host "平台: $platform" -ForegroundColor Gray

# 1. 更新 RitsuLib
if (-not $SkipRitsuLib) {
    Write-Host "`n[1/4] 更新 RitsuLib..." -ForegroundColor Yellow
    $ritsulibCache = Join-Path $cacheDir "ritsulib"
    if (Test-Path $ritsulibCache) {
        & $acquireRitsuScript -CacheDir $ritsulibCache -ForceUpdate
    } else {
        & $acquireRitsuScript -CacheDir $ritsulibCache
    }
} else {
    Write-Host "`n[1/4] 跳过 RitsuLib 更新" -ForegroundColor Gray
}

# 2. 更新教程
if (-not $SkipTutorials) {
    Write-Host "`n[2/4] 更新教程..." -ForegroundColor Yellow
    $tutorialsCache = Join-Path $cacheDir "tutorials"
    if (Test-Path $tutorialsCache) {
        & $acquireTutorialsScript -CacheDir $tutorialsCache -ForceUpdate
    } else {
        & $acquireTutorialsScript -CacheDir $tutorialsCache
    }
} else {
    Write-Host "`n[2/4] 跳过教程更新" -ForegroundColor Gray
}

# 3. 更新缓存索引
Write-Host "`n[3/4] 更新缓存索引..." -ForegroundColor Yellow
$ritsulibRoot = Join-Path $cacheDir "ritsulib"
$tutorialsRoot = Join-Path $cacheDir "tutorials"
$decompileDir = Join-Path $cacheDir "decompiled" "sts2"

& $buildIndexScript -RitsulibRoot $ritsulibRoot -GameSourceRoot $decompileDir -TutorialsRoot $tutorialsRoot -Force

# 4. 重建内置索引
Write-Host "`n[4/4] 重建内置索引..." -ForegroundColor Yellow
$buildArgs = @{}
if ($GameSourceRoot) {
    $buildArgs["GameSourceRoot"] = $GameSourceRoot
}
& $buildBuiltinScript @buildArgs

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  索引更新完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
