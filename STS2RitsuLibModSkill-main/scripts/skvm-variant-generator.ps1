<#
.SYNOPSIS
    SkVM 变体生成器 — 从能力画像生成优化的执行计划。

.DESCRIPTION
    读取 AOT 编译器输出的能力画像，为每个能力选择最佳实现路径，
    生成针对当前环境优化的执行变体。包含：
    - 能力到实现的映射
    - 回退策略的激活
    - 提示模板的适配
    - 缓存策略的设定

.PARAMETER ProfilePath
    能力画像文件路径，默认为 cache/skvm/capability-profile.json

.PARAMETER OutputPath
    输出变体文件路径，默认为 cache/skvm/compiled-variant.json

.EXAMPLE
    pwsh -File skvm-variant-generator.ps1
#>

param(
    [string]$ProfilePath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$skvmDir = Join-Path $skillRoot "cache" "skvm"

if (-not $ProfilePath) { $ProfilePath = Join-Path $skvmDir "capability-profile.json" }
if (-not $OutputPath) { $OutputPath = Join-Path $skvmDir "compiled-variant.json" }

# 加载能力画像
if (-not (Test-Path $ProfilePath)) {
    Write-Host "[ERROR] 能力画像不存在: $ProfilePath" -ForegroundColor Red
    Write-Host "请先运行 skvm-aot-compiler.ps1" -ForegroundColor Yellow
    exit 1
}

$profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json
$manifestPath = Join-Path $skillRoot "SKVM-MANIFEST.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SkVM 变体生成器" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================================
# 提示模板生成函数（必须在调用前定义）
# ============================================================

function Generate-PromptTemplate {
    param(
        [object]$Capability,
        [hashtable]$Mapping,
        [object]$Profile
    )

    $template = @{
        preconditions = @()
        instructions = @()
        fallbackInstructions = @()
        outputFormat = "auto"
    }

    switch ($Capability.id) {
        "source-discovery" {
            $template.preconditions += "检查 config.json 中是否已有路径配置"
            $template.preconditions += "检查 cache/ 目录中是否已有缓存资源"

            if ($Mapping.implementation -eq "primary") {
                $template.instructions += "运行 scripts/discover-roots.ps1 发现所有路径"
                $template.instructions += "将发现结果保存到 config.json"
            } else {
                $template.fallbackInstructions += "请用户手动提供游戏 DLL、RitsuLib、教程的路径"
                $template.fallbackInstructions += "将用户提供的路径写入 config.json"
            }
        }

        "source-acquisition" {
            $template.preconditions += "确认需要获取的资源类型"

            if ($Mapping.implementation -eq "primary") {
                $template.instructions += "根据缺失资源调用对应的获取脚本"
                $template.instructions += "RitsuLib: scripts/acquire-ritsulib.ps1"
                $template.instructions += "教程: scripts/acquire-tutorials.ps1"
                $template.instructions += "游戏源码: scripts/decompile-sts2.ps1"
            } else {
                if ($Mapping.selectedFallback -eq "use-offline-cache") {
                    $template.fallbackInstructions += "网络不可用，使用已有的缓存资源"
                    $template.fallbackInstructions += "检查 cache/ 目录中是否有可用的缓存"
                } elseif ($Mapping.selectedFallback -eq "skip-decompile") {
                    $template.fallbackInstructions += "跳过游戏反编译步骤"
                    $template.fallbackInstructions += "使用内置索引查询游戏内容"
                }
            }
        }

        "index-building" {
            $template.preconditions += "确认索引源数据是否可用"

            if ($Mapping.implementation -eq "primary") {
                $template.instructions += "运行 scripts/build-index.ps1 构建索引"
                $template.instructions += "索引输出到 cache/indexes/"
            } else {
                $template.fallbackInstructions += "使用 indexes/ 目录下的内置索引"
                $template.fallbackInstructions += "内置索引可能不是最新，但足以查询"
            }
        }

        "intelligent-query" {
            $template.preconditions += "确认索引是否已构建"

            if ($Mapping.implementation -eq "primary") {
                $template.instructions += "运行 scripts/query-index.ps1 查询"
                $template.instructions += "支持按类型、名称、关键词查询"
            } else {
                if ($Mapping.selectedFallback -eq "direct-json-search") {
                    $template.fallbackInstructions += "直接读取 indexes/ 目录下的 JSON 文件"
                    $template.fallbackInstructions += "使用 PowerShell 或其他方式解析 JSON"
                }
            }
        }

        "mod-scaffolding" {
            if ($Mapping.implementation -eq "primary") {
                $template.instructions += "运行 scripts/create-mod.ps1 创建项目"
                $template.instructions += "基于 NuGet 模板 STS2.RitsuLib.ModTemplate"
            } else {
                $template.fallbackInstructions += "提示用户安装 .NET SDK"
                $template.fallbackInstructions += "提供手动创建项目的步骤"
            }
        }
    }

    return $template
}

# ============================================================
# 生成能力实现映射
# ============================================================

Write-Host "[1/3] 生成能力实现映射..." -ForegroundColor Yellow

$capabilityMap = @{}

foreach ($cap in $manifest.capabilities) {
    $capId = $cap.id
    $probeResults = $profile.probes

    $mapping = @{
        id = $capId
        implementation = "primary"
        adaptations = @()
        promptTemplate = $null
        cachePolicy = $cap.cachePolicy
        timeout = $cap.timeout
    }

    # 检查每个依赖
    $missingDeps = @()

    foreach ($tool in $cap.requires.tools) {
        if ($tool -eq "pwsh" -and -not $probeResults.pwsh.available) {
            $missingDeps += "pwsh"
        }
        if ($tool -eq "git" -and -not $probeResults.git.available) {
            $missingDeps += "git"
        }
        if ($tool -eq "dotnet-sdk" -and -not $probeResults.'dotnet-sdk'.available) {
            $missingDeps += "dotnet-sdk"
        }
    }

    foreach ($envReq in $cap.requires.env) {
        if ($envReq -eq "network" -and -not $probeResults.network.available) {
            $missingDeps += "network"
        }
        if ($envReq -eq "dotnet-sdk" -and -not $probeResults.'dotnet-sdk'.available) {
            $missingDeps += "dotnet-sdk"
        }
    }

    # 如果有缺失依赖，选择回退
    if ($missingDeps.Count -gt 0) {
        $mapping.implementation = "fallback"

        foreach ($fallback in $cap.fallbacks) {
            $condition = $fallback.condition
            $matched = $false

            switch ($condition) {
                "no-pwsh" { $matched = $missingDeps -contains "pwsh" }
                "no-git" { $matched = $missingDeps -contains "git" }
                "no-dotnet" { $matched = $missingDeps -contains "dotnet-sdk" }
                "no-network" { $matched = $missingDeps -contains "network" }
                "no-ilspycmd" { $matched = -not $probeResults.ilspycmd.available }
                "no-steam" { $matched = -not $probeResults.'steam-install'.available }
                "no-indexes" {
                    $indexDir = Join-Path $skillRoot "indexes"
                    $matched = -not (Test-Path $indexDir)
                }
                "no-source-data" {
                    $matched = -not $probeResults.'steam-install'.available -and
                               -not $probeResults.git.available
                }
            }

            if ($matched) {
                $mapping.selectedFallback = $fallback.action
                $mapping.compensation = $fallback.compensation
                $mapping.adaptations += "fallback:$($fallback.action)"
                break
            }
        }
    }

    # 生成提示模板
    $mapping.promptTemplate = Generate-PromptTemplate -Capability $cap -Mapping $mapping -Profile $profile

    $capabilityMap[$capId] = $mapping

    $status = if ($mapping.implementation -eq "primary") { "[PRIMARY]" } else { "[FALLBACK]" }
    $color = if ($mapping.implementation -eq "primary") { "Green" } else { "Yellow" }
    $fallbackInfo = if ($mapping.selectedFallback) { " -> $($mapping.selectedFallback)" } else { "" }
    Write-Host "  $status $capId$fallbackInfo" -ForegroundColor $color
}

# ============================================================
# 生成执行计划
# ============================================================

Write-Host "`n[2/3] 生成执行计划..." -ForegroundColor Yellow

$dag = $manifest.workflow.dag
$executionPlan = @{
    orderedSteps = @()
    parallelGroups = @()
    cacheableSteps = @()
}

# 按 DAG 顺序排列步骤
$nodeOrder = @("discover", "acquire-ritsulib", "acquire-tutorials", "decompile-game", "build-index", "query", "create-mod")

foreach ($nodeId in $nodeOrder) {
    if (-not $dag.PSObject.Properties[$nodeId]) { continue }

    $node = $dag.$nodeId
    $capId = $node.capability
    $capMapping = $capabilityMap[$capId]

    $step = @{
        nodeId = $nodeId
        capability = $capId
        description = $node.description
        implementation = $capMapping.implementation
        fallback = $capMapping.selectedFallback
        compensation = $capMapping.compensation
        timeout = $capMapping.timeout
        cachePolicy = $capMapping.cachePolicy
        promptTemplate = $capMapping.promptTemplate
        parallel = $node.parallel
    }

    $executionPlan.orderedSteps += $step

    # 标记可缓存步骤
    if ($capMapping.cachePolicy -eq "solidify-after-5" -or $capMapping.cachePolicy -eq "solidify-after-3") {
        $executionPlan.cacheableSteps += $nodeId
    }
}

# 识别并行组
$currentParallelGroup = @()
foreach ($step in $executionPlan.orderedSteps) {
    if ($step.parallel) {
        $currentParallelGroup += $step.nodeId
    } else {
        if ($currentParallelGroup.Count -gt 1) {
            $executionPlan.parallelGroups += , $currentParallelGroup
        }
        $currentParallelGroup = @()
    }
}
if ($currentParallelGroup.Count -gt 1) {
    $executionPlan.parallelGroups += , $currentParallelGroup
}

Write-Host "  步骤数: $($executionPlan.orderedSteps.Count)" -ForegroundColor Gray
Write-Host "  并行组: $($executionPlan.parallelGroups.Count)" -ForegroundColor Gray
Write-Host "  可缓存: $($executionPlan.cacheableSteps.Count)" -ForegroundColor Gray

# ============================================================
# 输出编译变体
# ============================================================

Write-Host "`n[3/3] 输出编译变体..." -ForegroundColor Yellow

$variant = @{
    skvmVersion = $manifest.skvmVersion
    skillVersion = $manifest.version
    timestamp = (Get-Date -Format "o")
    platform = $profile.platform
    environment = @{
        pwsh = $profile.probes.pwsh.available
        dotnet = $profile.probes.'dotnet-sdk'.available
        git = $profile.probes.git.available
        ilspycmd = $profile.probes.ilspycmd.available
        network = $profile.probes.network.available
        steam = $profile.probes.'steam-install'.available
    }
    capabilities = $capabilityMap
    executionPlan = $executionPlan
    solidification = @{
        enabled = $true
        threshold = $manifest.solidification.stableThreshold
        cacheDir = $manifest.solidification.cacheDir
    }
    recompilation = @{
        failureThreshold = $manifest.recompilation.failureThreshold
        cooldownMs = $manifest.recompilation.cooldownMs
        maxVariants = $manifest.recompilation.maxVariants
    }
}

$variant | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  变体生成完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n输出: $OutputPath" -ForegroundColor Gray
Write-Host "主实现: $(($capabilityMap.Values | Where-Object { $_.implementation -eq 'primary' }).Count) 个" -ForegroundColor Gray
Write-Host "回退: $(($capabilityMap.Values | Where-Object { $_.implementation -eq 'fallback' }).Count) 个" -ForegroundColor Gray
Write-Host ""
