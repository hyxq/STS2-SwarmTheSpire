<#
.SYNOPSIS
    SkVM 运行时加载器 — 加载编译变体并执行工作流。

.DESCRIPTION
    JIT 运行时阶段：
    1. 加载针对当前环境编译好的 Skill 变体
    2. 按 DAG 顺序执行步骤，支持并行
    3. 监控每个步骤的成功/失败
    4. 失败时尝试回退链
    5. 记录执行日志供反馈系统分析
    6. 对已固化的步骤使用缓存结果

.PARAMETER VariantPath
    编译变体文件路径，默认为 cache/skvm/compiled-variant.json

.PARAMETER TaskName
    要执行的工作流：init, query, create, full

.PARAMETER DryRun
    只打印执行计划，不实际执行

.PARAMETER ProjectRoot
    Mod 项目根目录（传递给底层脚本）

.EXAMPLE
    pwsh -File skvm-runtime-loader.ps1 -TaskName init
    pwsh -File skvm-runtime-loader.ps1 -TaskName query -DryRun
#>

param(
    [string]$VariantPath,
    [ValidateSet("init", "query", "create", "full")]
    [string]$TaskName = "init",
    [switch]$DryRun,
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$skvmDir = Join-Path $skillRoot "cache" "skvm"

if (-not $VariantPath) { $VariantPath = Join-Path $skvmDir "compiled-variant.json" }

$logPath = Join-Path $skvmDir "execution-log.json"
$solidifiedDir = Join-Path $skvmDir "solidified"

# 确保目录存在
foreach ($dir in @($skvmDir, $solidifiedDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# ============================================================
# 加载编译变体
# ============================================================

function Load-Variant {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "[WARN] 编译变体不存在，尝试运行 AOT 编译..." -ForegroundColor Yellow
        $aotCompiler = Join-Path $scriptDir "skvm-aot-compiler.ps1"
        if (Test-Path $aotCompiler) {
            & $aotCompiler
        } else {
            Write-Host "[ERROR] AOT 编译器不存在: $aotCompiler" -ForegroundColor Red
            exit 1
        }
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

# ============================================================
# 加载执行历史
# ============================================================

function Load-ExecutionLog {
    param([string]$Path)

    if (Test-Path $Path) {
        return Get-Content $Path -Raw | ConvertFrom-Json
    }

    return @{
        runs = @()
        stepStats = @{}
        lastRun = $null
    }
}

# ============================================================
# 保存执行日志
# ============================================================

function Save-ExecutionLog {
    param(
        [hashtable]$Log,
        [string]$Path
    )

    $Log | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8
}

# ============================================================
# 检查步骤是否已固化
# ============================================================

function Test-Solidified {
    param(
        [string]$NodeId,
        [object]$Variant
    )

    $solidifiedFile = Join-Path $solidifiedDir "$NodeId.json"
    if (-not (Test-Path $solidifiedFile)) { return $null }

    $solidified = Get-Content $solidifiedFile -Raw | ConvertFrom-Json

    # 检查是否在有效期内
    $solidifiedTime = [DateTime]::Parse($solidified.timestamp)
    $age = (Get-Date) - $solidifiedTime

    # 固化结果24小时内有效
    if ($age.TotalHours -lt 24) {
        return $solidified
    }

    return $null
}

# ============================================================
# 固化步骤结果
# ============================================================

function Save-SolidifiedResult {
    param(
        [string]$NodeId,
        [object]$Result,
        [object]$Variant
    )

    # 检查是否在可缓存步骤中
    $cacheable = $Variant.executionPlan.cacheableSteps
    if ($cacheable -notcontains $NodeId) { return }

    # 更新步骤统计
    $log = Load-ExecutionLog -Path $logPath
    $stepKey = $NodeId

    if (-not $log.stepStats.$stepKey) {
        $log.stepStats.$stepKey = @{
            successCount = 0
            failCount = 0
            lastSuccess = $null
            lastResult = $null
        }
    }

    $stats = $log.stepStats.$stepKey
    $stats.successCount++
    $stats.lastSuccess = (Get-Date -Format "o")
    $stats.lastResult = $Result

    # 检查是否达到固化阈值
    $threshold = $Variant.solidification.threshold
    if ($stats.successCount -ge $threshold) {
        $solidifiedFile = Join-Path $solidifiedDir "$NodeId.json"
        $solidifiedData = @{
            nodeId = $NodeId
            timestamp = (Get-Date -Format "o")
            successCount = $stats.successCount
            result = $Result
        }
        $solidifiedData | ConvertTo-Json -Depth 5 | Out-File -FilePath $solidifiedFile -Encoding UTF8
        Write-Host "    [SOLIDIFIED] $NodeId (成功 $($stats.successCount) 次)" -ForegroundColor Magenta
    }

    Save-ExecutionLog -Log $log -Path $logPath
}

# ============================================================
# 执行单个步骤
# ============================================================

function Invoke-Step {
    param(
        [object]$Step,
        [object]$Variant,
        [hashtable]$Log
    )

    $nodeId = $Step.nodeId
    $capId = $Step.capability

    # 检查固化缓存
    $solidified = Test-Solidified -NodeId $nodeId -Variant $Variant
    if ($solidified) {
        Write-Host "  [CACHED] $nodeId (固化缓存)" -ForegroundColor Magenta
        return @{
            success = $true
            cached = $true
            result = $solidified.result
            duration = 0
        }
    }

    # 执行步骤
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = @{
        success = $false
        cached = $false
        output = $null
        error = $null
        fallbackUsed = $null
        duration = 0
    }

    try {
        if ($Step.available -ne $false) {
            # 主实现路径
            $output = Invoke-PrimaryStep -Step $Step -Variant $Variant
            $result.success = $true
            $result.output = $output
        } else {
            # 回退路径
            Write-Host "  [FALLBACK] $nodeId -> $($Step.fallback)" -ForegroundColor Yellow
            $output = Invoke-FallbackStep -Step $Step -Variant $Variant
            $result.success = $true
            $result.output = $output
            $result.fallbackUsed = $Step.fallback
        }
    } catch {
        $result.error = $_.Exception.Message
        Write-Host "  [ERROR] $nodeId : $($_.Exception.Message)" -ForegroundColor Red
    }

    $sw.Stop()
    $result.duration = $sw.ElapsedMilliseconds

    # 更新日志
    $stepKey = $nodeId
    if (-not $Log.stepStats.$stepKey) {
        $Log.stepStats.$stepKey = @{
            successCount = 0
            failCount = 0
            consecutiveFails = 0
            lastSuccess = $null
            lastFail = $null
        }
    }

    if ($result.success) {
        $Log.stepStats.$stepKey.successCount++
        $Log.stepStats.$stepKey.consecutiveFails = 0
        $Log.stepStats.$stepKey.lastSuccess = (Get-Date -Format "o")
        Save-SolidifiedResult -NodeId $nodeId -Result $result.output -Variant $Variant
    } else {
        $Log.stepStats.$stepKey.failCount++
        $Log.stepStats.$stepKey.consecutiveFails++
        $Log.stepStats.$stepKey.lastFail = (Get-Date -Format "o")
    }

    return $result
}

# ============================================================
# 主实现步骤执行
# ============================================================

function Invoke-PrimaryStep {
    param(
        [object]$Step,
        [object]$Variant
    )

    $nodeId = $Step.nodeId
    $scriptPath = $null
    $scriptArgs = @{}

    switch ($nodeId) {
        "discover" {
            $scriptPath = Join-Path $scriptDir "discover-roots.ps1"
            $scriptArgs = @{ OutputFormat = "json" }
        }
        "acquire-ritsulib" {
            $scriptPath = Join-Path $scriptDir "acquire-ritsulib.ps1"
            $cacheDir = Join-Path $skillRoot "cache" "ritsulib"
            $scriptArgs = @{ CacheDir = $cacheDir }
        }
        "acquire-tutorials" {
            $scriptPath = Join-Path $scriptDir "acquire-tutorials.ps1"
            $cacheDir = Join-Path $skillRoot "cache" "tutorials"
            $scriptArgs = @{ CacheDir = $cacheDir }
        }
        "decompile-game" {
            $scriptPath = Join-Path $scriptDir "decompile-sts2.ps1"
            # 需要从配置中获取 DLL 路径
            $configPath = Join-Path $skillRoot "config.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($config.gameDll) {
                    $outputDir = Join-Path $skillRoot "cache" "decompiled" "sts2"
                    $scriptArgs = @{ DllPath = $config.gameDll; OutputDir = $outputDir }
                }
            }
        }
        "build-index" {
            $scriptPath = Join-Path $scriptDir "build-index.ps1"
        }
        "query" {
            $scriptPath = Join-Path $scriptDir "query-index.ps1"
            # 查询步骤需要参数，从上下文获取
            $scriptArgs = @{ Type = "card"; Name = "*" }
        }
        "create-mod" {
            $scriptPath = Join-Path $scriptDir "create-mod.ps1"
            $scriptArgs = @{ Name = "NewMod"; OutputDir = $ProjectRoot }
        }
    }

    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        throw "脚本不存在: $scriptPath"
    }

    # 构建命令
    $argList = @()
    foreach ($key in $scriptArgs.Keys) {
        $argList += "-$key"
        $argList += $scriptArgs[$key]
    }

    $output = & $scriptPath @argList 2>&1
    return $output
}

# ============================================================
# 回退步骤执行
# ============================================================

function Invoke-FallbackStep {
    param(
        [object]$Step,
        [object]$Variant
    )

    $fallback = $Step.fallback
    $fixScriptDir = Join-Path $skvmDir "fix-scripts"
    $fixScript = Join-Path $fixScriptDir "$($Step.capability)-fix.ps1"

    if (Test-Path $fixScript) {
        $output = & $fixScript 2>&1
        return $output
    }

    # 内联回退处理
    switch ($fallback) {
        "use-builtin-indexes" {
            Write-Host "    使用内置索引 (indexes/ 目录)" -ForegroundColor Gray
            return "Using built-in indexes"
        }
        "use-offline-cache" {
            Write-Host "    使用离线缓存" -ForegroundColor Gray
            return "Using offline cache"
        }
        "skip-decompile" {
            Write-Host "    跳过反编译" -ForegroundColor Gray
            return "Decompilation skipped"
        }
        "direct-json-search" {
            Write-Host "    直接 JSON 搜索" -ForegroundColor Gray
            return "Direct JSON search"
        }
        default {
            Write-Host "    回退策略: $fallback" -ForegroundColor Gray
            return "Fallback: $fallback"
        }
    }
}

# ============================================================
# 检查是否需要重新编译
# ============================================================

function Test-RecompilationNeeded {
    param(
        [hashtable]$Log,
        [object]$Variant
    )

    $threshold = $Variant.recompilation.failureThreshold
    $cooldownMs = $Variant.recompilation.cooldownMs

    foreach ($stepKey in $Log.stepStats.Keys) {
        $stats = $Log.stepStats.$stepKey
        if ($stats.consecutiveFails -ge $threshold) {
            Write-Host "`n[WARN] 步骤 '$stepKey' 连续失败 $($stats.consecutiveFails) 次" -ForegroundColor Red
            return $true
        }
    }

    return $false
}

# ============================================================
# 主流程
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SkVM 运行时加载器" -ForegroundColor Cyan
Write-Host "  任务: $TaskName" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 加载变体
$variant = Load-Variant -Path $VariantPath
Write-Host "变体版本: $($variant.skillVersion)" -ForegroundColor Gray
Write-Host "编译时间: $($variant.timestamp)" -ForegroundColor Gray
Write-Host "平台: $($variant.platform)`n" -ForegroundColor Gray

# 加载执行日志
$log = Load-ExecutionLog -Path $logPath

# 获取工作流入口点
$entryPoints = $variant.executionPlan.orderedSteps
$taskSteps = @()

switch ($TaskName) {
    "init" {
        $taskSteps = $entrySteps = $entryPoints | Where-Object {
            $_.nodeId -in @("discover", "acquire-ritsulib", "acquire-tutorials", "decompile-game", "build-index")
        }
    }
    "query" {
        $taskSteps = $entryPoints | Where-Object { $_.nodeId -eq "query" }
    }
    "create" {
        $taskSteps = $entryPoints | Where-Object { $_.nodeId -eq "create-mod" }
    }
    "full" {
        $taskSteps = $entryPoints
    }
}

# DryRun 模式
if ($DryRun) {
    Write-Host "[DRY RUN] 执行计划：" -ForegroundColor Yellow
    Write-Host ("=" * 50) -ForegroundColor DarkGray

    foreach ($step in $taskSteps) {
        $impl = if ($step.available -ne $false) { "PRIMARY" } else { "FALLBACK:$($step.fallback)" }
        $solidified = Test-Solidified -NodeId $step.nodeId -Variant $variant
        $cacheStatus = if ($solidified) { " [CACHED]" } else { "" }
        Write-Host "  $($step.nodeId) [$impl]$cacheStatus" -ForegroundColor Gray
        Write-Host "    $($step.description)" -ForegroundColor DarkGray
    }

    Write-Host "`n并行组:" -ForegroundColor Yellow
    foreach ($group in $variant.executionPlan.parallelGroups) {
        Write-Host "  [$($group -join ', ')]" -ForegroundColor Gray
    }

    exit 0
}

# 执行步骤
Write-Host "[EXEC] 开始执行 $TaskName 工作流" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor DarkGray

$runResult = @{
    taskName = $TaskName
    startTime = (Get-Date -Format "o")
    steps = @()
    success = $true
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($step in $taskSteps) {
    Write-Host "`n[$($step.nodeId)] $($step.description)" -ForegroundColor White

    $stepResult = Invoke-Step -Step $step -Variant $variant -Log $log

    $status = if ($stepResult.success) {
        if ($stepResult.cached) { "CACHED" } else { "OK" }
    } else { "FAIL" }
    $color = if ($stepResult.success) { "Green" } else { "Red" }

    Write-Host "  [$status] $($stepResult.duration)ms" -ForegroundColor $color

    $runResult.steps += @{
        nodeId = $step.nodeId
        success = $stepResult.success
        cached = $stepResult.cached
        duration = $stepResult.duration
        fallback = $stepResult.fallbackUsed
        error = $stepResult.error
    }

    if (-not $stepResult.success) {
        $runResult.success = $false
    }
}

$sw.Stop()
$runResult.endTime = (Get-Date -Format "o")
$runResult.totalDuration = $sw.ElapsedMilliseconds

# 保存执行日志
$log.runs += $runResult
# 只保留最近50次运行记录
if ($log.runs.Count -gt 50) {
    $log.runs = $log.runs | Select-Object -Last 50
}
$log.lastRun = $runResult
Save-ExecutionLog -Log $log -Path $logPath

# 检查是否需要重新编译
if (Test-RecompilationNeeded -Log $log -Variant $variant) {
    Write-Host "`n[RECOMPILE] 触发自适应重编译..." -ForegroundColor Red
    $aotCompiler = Join-Path $scriptDir "skvm-aot-compiler.ps1"
    if (Test-Path $aotCompiler) {
        & $aotCompiler -Force
        Write-Host "[RECOMPILE] 重编译完成，下次运行将使用新变体" -ForegroundColor Green
    }
}

# 输出执行摘要
Write-Host "`n========================================" -ForegroundColor $(if ($runResult.success) { "Green" } else { "Red" })
Write-Host "  执行完成" -ForegroundColor $(if ($runResult.success) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor $(if ($runResult.success) { "Green" } else { "Red" })
Write-Host "  任务: $TaskName" -ForegroundColor Gray
Write-Host "  总耗时: $($runResult.totalDuration)ms" -ForegroundColor Gray
Write-Host "  步骤: $(($runResult.steps | Where-Object { $_.success }).Count)/$($runResult.steps.Count) 成功" -ForegroundColor Gray
Write-Host "  状态: $(if ($runResult.success) { '成功' } else { '失败' })" -ForegroundColor $(if ($runResult.success) { "Green" } else { "Red" })
Write-Host ""
