<#
.SYNOPSIS
    SkVM 反馈收集器 — 分析执行日志，触发自适应重编译。

.DESCRIPTION
    反馈循环机制：
    1. 读取执行日志，分析失败模式
    2. 检测连续失败的步骤（阈值: 3次）
    3. 触发重编译（如果需要）
    4. 对稳定步骤进行固化
    5. 生成反馈报告
    6. 管理变体回滚

.PARAMETER LogPath
    执行日志路径，默认为 cache/skvm/execution-log.json

.PARAMETER Recompile
    强制触发重编译

.PARAMETER Report
    只生成反馈报告，不触发重编译

.EXAMPLE
    pwsh -File skvm-feedback-collector.ps1
    pwsh -File skvm-feedback-collector.ps1 -Recompile
    pwsh -File skvm-feedback-collector.ps1 -Report
#>

param(
    [string]$LogPath,
    [switch]$Recompile,
    [switch]$Report
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$skvmDir = Join-Path $skillRoot "cache" "skvm"
$solidifiedDir = Join-Path $skvmDir "solidified"
$variantPath = Join-Path $skvmDir "compiled-variant.json"
$historyDir = Join-Path $skvmDir "variant-history"

if (-not $LogPath) { $LogPath = Join-Path $skvmDir "execution-log.json" }

# 确保目录存在
foreach ($dir in @($skvmDir, $solidifiedDir, $historyDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SkVM 反馈收集器" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================================
# 加载执行日志
# ============================================================

if (-not (Test-Path $LogPath)) {
    Write-Host "[INFO] 执行日志不存在，跳过分析" -ForegroundColor Yellow
    exit 0
}

$log = Get-Content $LogPath -Raw | ConvertFrom-Json
$variant = $null
if (Test-Path $variantPath) {
    $variant = Get-Content $variantPath -Raw | ConvertFrom-Json
}

# ============================================================
# 分析失败模式
# ============================================================

Write-Host "[1/4] 分析执行日志..." -ForegroundColor Yellow

$analysis = @{
    totalRuns = 0
    successRuns = 0
    failRuns = 0
    stepAnalysis = @{}
    failurePatterns = @()
    recommendations = @()
}

if ($log.runs) {
    $analysis.totalRuns = $log.runs.Count
    $analysis.successRuns = ($log.runs | Where-Object { $_.success }).Count
    $analysis.failRuns = $analysis.totalRuns - $analysis.successRuns
}

# 分析每个步骤
if ($log.stepStats) {
    foreach ($prop in $log.stepStats.PSObject.Properties) {
        $stepName = $prop.Name
        $stats = $prop.Value

        $stepAnalysis = @{
            name = $stepName
            successRate = if (($stats.successCount + $stats.failCount) -gt 0) {
                [Math]::Round($stats.successCount / ($stats.successCount + $stats.failCount) * 100, 1)
            } else { 0 }
            consecutiveFails = $stats.consecutiveFails
            totalSuccess = $stats.successCount
            totalFail = $stats.failCount
            needsAttention = $false
        }

        # 检测需要关注的步骤
        if ($stats.consecutiveFails -ge 3) {
            $stepAnalysis.needsAttention = $true
            $analysis.failurePatterns += @{
                step = $stepName
                type = "consecutive-failure"
                count = $stats.consecutiveFails
                severity = "high"
            }
        }

        if ($stepAnalysis.successRate -lt 50 -and ($stats.successCount + $stats.failCount) -ge 3) {
            $stepAnalysis.needsAttention = $true
            $analysis.failurePatterns += @{
                step = $stepName
                type = "low-success-rate"
                rate = $stepAnalysis.successRate
                severity = "medium"
            }
        }

        $analysis.stepAnalysis[$stepName] = $stepAnalysis
    }
}

# 输出分析结果
Write-Host "  总运行次数: $($analysis.totalRuns)" -ForegroundColor Gray
Write-Host "  成功: $($analysis.successRuns), 失败: $($analysis.failRuns)" -ForegroundColor Gray
Write-Host "  失败模式: $($analysis.failurePatterns.Count) 个" -ForegroundColor Gray

# ============================================================
# 生成建议
# ============================================================

Write-Host "`n[2/4] 生成优化建议..." -ForegroundColor Yellow

foreach ($pattern in $analysis.failurePatterns) {
    switch ($pattern.type) {
        "consecutive-failure" {
            $analysis.recommendations += @{
                type = "recompile"
                step = $pattern.step
                reason = "步骤 '$($pattern.step)' 连续失败 $($pattern.count) 次"
                action = "触发环境重探针和变体重编译"
                priority = "high"
            }
        }
        "low-success-rate" {
            $analysis.recommendations += @{
                type = "investigate"
                step = $pattern.step
                reason = "步骤 '$($pattern.step)' 成功率仅 $($pattern.rate)%"
                action = "检查环境配置或回退策略"
                priority = "medium"
            }
        }
    }
}

# 检查固化候选
foreach ($stepName in $analysis.stepAnalysis.Keys) {
    $step = $analysis.stepAnalysis[$stepName]
    if ($step.totalSuccess -ge 5 -and $step.consecutiveFails -eq 0) {
        $solidifiedFile = Join-Path $solidifiedDir "$stepName.json"
        if (-not (Test-Path $solidifiedFile)) {
            $analysis.recommendations += @{
                type = "solidify"
                step = $stepName
                reason = "步骤 '$stepName' 已连续成功 $($step.totalSuccess) 次"
                action = "可以固化为缓存结果"
                priority = "low"
            }
        }
    }
}

foreach ($rec in $analysis.recommendations) {
    $color = switch ($rec.priority) {
        "high" { "Red" }
        "medium" { "Yellow" }
        "low" { "Gray" }
    }
    Write-Host "  [$($rec.type)] $($rec.reason)" -ForegroundColor $color
}

# ============================================================
# 生成反馈报告
# ============================================================

Write-Host "`n[3/4] 生成反馈报告..." -ForegroundColor Yellow

$feedbackReport = @{
    timestamp = (Get-Date -Format "o")
    analysis = $analysis
    recommendations = $analysis.recommendations
    environmentSummary = @{}
}

if ($variant) {
    $feedbackReport.environmentSummary = @{
        platform = $variant.platform
        pwsh = $variant.environment.pwsh
        dotnet = $variant.environment.dotnet
        git = $variant.environment.git
        ilspycmd = $variant.environment.ilspycmd
        network = $variant.environment.network
    }
}

$reportPath = Join-Path $skvmDir "feedback-report.json"
$feedbackReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "  报告已保存: $reportPath" -ForegroundColor Gray

# ============================================================
# 触发重编译（如果需要）
# ============================================================

Write-Host "`n[4/4] 检查重编译条件..." -ForegroundColor Yellow

$shouldRecompile = $Recompile
$recompileReason = $null

if (-not $shouldRecompile) {
    # 检查是否有高优先级建议
    foreach ($rec in $analysis.recommendations) {
        if ($rec.type -eq "recompile" -and $rec.priority -eq "high") {
            $shouldRecompile = $true
            $recompileReason = $rec.reason
            break
        }
    }
}

if ($shouldRecompile) {
    if ($recompileReason) {
        Write-Host "  [RECOMPILE] $recompileReason" -ForegroundColor Red
    } else {
        Write-Host "  [RECOMPILE] 强制重编译" -ForegroundColor Yellow
    }

    # 保存当前变体到历史
    if (Test-Path $variantPath) {
        $historyFile = Join-Path $historyDir "variant-pre-recompile-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        Copy-Item -Path $variantPath -Destination $historyFile
        Write-Host "  已保存当前变体到历史" -ForegroundColor Gray
    }

    # 运行 AOT 编译器
    $aotCompiler = Join-Path $scriptDir "skvm-aot-compiler.ps1"
    if (Test-Path $aotCompiler) {
        Write-Host "  运行 AOT 编译器..." -ForegroundColor Cyan
        & $aotCompiler -Force
        Write-Host "  重编译完成" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] AOT 编译器不存在" -ForegroundColor Red
    }
} else {
    Write-Host "  无需重编译" -ForegroundColor Green
}

# ============================================================
# 输出摘要
# ============================================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  反馈分析完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  运行次数: $($analysis.totalRuns)" -ForegroundColor Gray
Write-Host "  成功率: $(if ($analysis.totalRuns -gt 0) { [Math]::Round($analysis.successRuns / $analysis.totalRuns * 100, 1) } else { 0 })%" -ForegroundColor Gray
Write-Host "  失败模式: $($analysis.failurePatterns.Count)" -ForegroundColor Gray
Write-Host "  建议数: $($analysis.recommendations.Count)" -ForegroundColor Gray
Write-Host "  重编译: $(if ($shouldRecompile) { '已触发' } else { '未触发' })" -ForegroundColor Gray
Write-Host "  报告: $reportPath" -ForegroundColor Gray
Write-Host ""
