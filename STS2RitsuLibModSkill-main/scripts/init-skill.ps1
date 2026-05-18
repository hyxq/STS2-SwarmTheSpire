<#
.SYNOPSIS
    初始化 STS2RitsuLibMod Skill 环境（跨平台）。

.DESCRIPTION
    执行完整的初始化流程：
    1. 发现路径
    2. 自动拉取 RitsuLib（如需要）
    3. 自动拉取教程（如需要）
    4. 反编译游戏（如需要）
    5. 构建索引

.PARAMETER ProjectRoot
    Mod 项目根目录

.PARAMETER SkipDecompile
    跳过反编译步骤

.EXAMPLE
    pwsh -File init-skill.ps1
    pwsh -File init-skill.ps1 -ProjectRoot ~/Projects/MyMod -SkipDecompile
#>

param(
    [string]$ProjectRoot = ".",
    [switch]$SkipDecompile
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$cacheDir = Join-Path $skillRoot "cache"

# 脚本路径（使用 Join-Path 确保跨平台兼容）
$discoverScript = Join-Path $scriptDir "discover-roots.ps1"
$acquireRitsuScript = Join-Path $scriptDir "acquire-ritsulib.ps1"
$acquireTutorialsScript = Join-Path $scriptDir "acquire-tutorials.ps1"
$decompileScript = Join-Path $scriptDir "decompile-sts2.ps1"
$buildIndexScript = Join-Path $scriptDir "build-index.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STS2RitsuLibMod Skill 初始化" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 显示平台信息
$platform = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }
Write-Host "平台: $platform" -ForegroundColor Gray

# 1. 发现路径
Write-Host "`n[1/5] 发现路径..." -ForegroundColor Yellow
$discovered = & $discoverScript -ProjectRoot $ProjectRoot -OutputFormat json | ConvertFrom-Json

$gameDll = $discovered.gameDll
$ritsulibRoot = $discovered.ritsulibRoot
$tutorialsRoot = $discovered.tutorialsRoot
$gameSourceRoot = $discovered.gameSourceRoot

Write-Host "  Game DLL: $($gameDll ?? '未找到')" -ForegroundColor Gray
Write-Host "  Game Source: $($gameSourceRoot ?? '未找到')" -ForegroundColor Gray
Write-Host "  RitsuLib: $($ritsulibRoot ?? '未找到，将自动拉取')" -ForegroundColor Gray
Write-Host "  Tutorials: $($tutorialsRoot ?? '未找到，将自动拉取')" -ForegroundColor Gray

# 2. 获取 RitsuLib
Write-Host "`n[2/5] 获取 RitsuLib..." -ForegroundColor Yellow
if (-not $ritsulibRoot) {
    $ritsulibCache = Join-Path $cacheDir "ritsulib"
    try {
        & $acquireRitsuScript -CacheDir $ritsulibCache
        $ritsulibRoot = $ritsulibCache
    } catch {
        Write-Host "  [WARN] 无法获取 RitsuLib: $_" -ForegroundColor Yellow
        Write-Host "  请手动设置 RitsuLib 路径或检查网络连接" -ForegroundColor Yellow
    }
} else {
    Write-Host "  使用已有 RitsuLib: $ritsulibRoot" -ForegroundColor Green
}

# 3. 获取教程
Write-Host "`n[3/5] 获取教程..." -ForegroundColor Yellow
if (-not $tutorialsRoot) {
    $tutorialsCache = Join-Path $cacheDir "tutorials"
    try {
        & $acquireTutorialsScript -CacheDir $tutorialsCache
        $tutorialsRoot = $tutorialsCache
    } catch {
        Write-Host "  [WARN] 无法获取教程: $_" -ForegroundColor Yellow
        Write-Host "  请手动设置教程路径或检查网络连接" -ForegroundColor Yellow
    }
} else {
    Write-Host "  使用已有教程: $tutorialsRoot" -ForegroundColor Green
}

# 4. 反编译游戏（跨平台支持）
Write-Host "`n[4/5] 反编译游戏..." -ForegroundColor Yellow
if ($SkipDecompile) {
    Write-Host "  跳过反编译" -ForegroundColor Gray
} elseif (-not $gameDll) {
    Write-Host "  未找到游戏 DLL，跳过反编译" -ForegroundColor Yellow
} elseif (-not $gameSourceRoot) {
    $decompileCache = Join-Path $cacheDir "decompiled" "sts2"
    try {
        & $decompileScript -DllPath $gameDll -OutputDir $decompileCache
        $gameSourceRoot = $decompileCache
    } catch {
        Write-Host "  [WARN] 反编译失败: $_" -ForegroundColor Yellow
        Write-Host "  请确保已安装 ilspycmd: dotnet tool install -g ilspycmd" -ForegroundColor Yellow
    }
} else {
    Write-Host "  使用已有反编译源码: $gameSourceRoot" -ForegroundColor Green
}

# 5. 构建索引
Write-Host "`n[5/5] 构建索引..." -ForegroundColor Yellow
& $buildIndexScript -RitsulibRoot $ritsulibRoot -GameSourceRoot $gameSourceRoot -TutorialsRoot $tutorialsRoot

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  初始化完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 输出配置摘要
Write-Host "`n配置摘要：" -ForegroundColor Cyan
Write-Host "  平台: $platform" -ForegroundColor Gray
Write-Host "  缓存目录: $cacheDir" -ForegroundColor Gray
Write-Host "  RitsuLib: $($ritsulibRoot ?? '未获取')" -ForegroundColor Gray
Write-Host "  教程: $($tutorialsRoot ?? '未获取')" -ForegroundColor Gray
Write-Host "  游戏源码: $($gameSourceRoot ?? '未反编译')" -ForegroundColor Gray

Write-Host "`n使用示例：" -ForegroundColor Cyan
Write-Host "  查询教程: pwsh -File scripts/query-index.ps1 -Type tutorial -Keyword '卡牌'" -ForegroundColor Gray
Write-Host "  查询 API: pwsh -File scripts/query-index.ps1 -Type ritsulib-api -Keyword 'Register'" -ForegroundColor Gray
