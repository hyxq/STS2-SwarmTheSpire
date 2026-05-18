<#
.SYNOPSIS
    SkVM AOT 编译器 — 为当前环境编译 Skill 变体。

.DESCRIPTION
    三步编译流程：
    1. 能力画像（Capability Profiling）：运行环境探针，记录工具可用性和版本
    2. 环境绑定（Environment Binding）：检查依赖，生成修复脚本
    3. DAG 提取（DAG Extraction）：验证工作流依赖图，生成执行计划

    输出：
    - cache/skvm/capability-profile.json — 环境探针结果
    - cache/skvm/compiled-variant.json — 编译后的执行计划
    - cache/skvm/fix-scripts/ — 环境修复脚本

.PARAMETER ManifestPath
    清单文件路径，默认为 Skill 根目录下的 SKVM-MANIFEST.json

.PARAMETER Force
    强制重新运行所有探针（忽略缓存）

.EXAMPLE
    pwsh -File skvm-aot-compiler.ps1
    pwsh -File skvm-aot-compiler.ps1 -Force
#>

param(
    [string]$ManifestPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $skillRoot "SKVM-MANIFEST.json"
}

$cacheDir = Join-Path $skillRoot "cache"
$skvmDir = Join-Path $cacheDir "skvm"
$profilePath = Join-Path $skvmDir "capability-profile.json"
$variantPath = Join-Path $skvmDir "compiled-variant.json"
$fixScriptsDir = Join-Path $skvmDir "fix-scripts"

# 确保目录存在
foreach ($dir in @($skvmDir, $fixScriptsDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# ============================================================
# Step 1: 能力画像（Capability Profiling）
# ============================================================

function Invoke-CapabilityProfiling {
    param([hashtable]$Manifest)

    Write-Host "`n[Step 1/3] 能力画像 — 环境探针扫描" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor DarkGray

    $profile = @{
        timestamp = (Get-Date -Format "o")
        platform = if ($IsWindows) { "windows" } elseif ($IsMacOS) { "macos" } else { "linux" }
        probes = @{}
        summary = @{
            totalProbes = 0
            available = 0
            unavailable = 0
            critical = @{ total = 0; passed = 0 }
        }
    }

    foreach ($probe in $Manifest.environment.probes) {
        $probeId = $probe.id
        $probeResult = @{
            id = $probeId
            name = $probe.name
            type = $probe.type
            critical = $probe.critical
            available = $false
            version = $null
            latency = 0
            details = $null
            error = $null
        }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            switch ($probe.type) {
                "command" {
                    $output = Invoke-Expression "$($probe.command) 2>&1" -ErrorAction SilentlyContinue
                    $exitCode = $LASTEXITCODE
                    $sw.Stop()

                    if ($exitCode -eq 0 -or ($output -and $output -notmatch "not recognized|not found")) {
                        $probeResult.available = $true
                        $probeResult.details = ($output | Select-Object -First 3) -join "`n"

                        # 提取版本号
                        if ($probe.versionRegex) {
                            $versionMatch = [regex]::Match(($output -join " "), $probe.versionRegex)
                            if ($versionMatch.Success) {
                                $probeResult.version = $versionMatch.Groups[1].Value
                            }
                        }
                    } else {
                        $probeResult.error = ($output | Select-Object -First 2) -join "`n"
                    }
                }

                "registry-or-path" {
                    $found = $false
                    $foundPath = $null

                    # Windows 注册表检查
                    if ($IsWindows -and $probe.windowsRegistry) {
                        foreach ($regPath in $probe.windowsRegistry) {
                            if (Test-Path $regPath) {
                                $installPath = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).InstallPath
                                if ($installPath -and (Test-Path $installPath)) {
                                    $found = $true
                                    $foundPath = $installPath
                                    break
                                }
                            }
                        }
                    }

                    # 默认路径检查
                    if (-not $found -and $probe.defaultPaths) {
                        $platformKey = if ($IsWindows) { "windows" } elseif ($IsMacOS) { "macos" } else { "linux" }
                        $paths = $probe.defaultPaths[$platformKey]
                        foreach ($path in $paths) {
                            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)
                            if ($expandedPath -and (Test-Path $expandedPath)) {
                                $found = $true
                                $foundPath = $expandedPath
                                break
                            }
                        }
                    }

                    $sw.Stop()
                    $probeResult.available = $found
                    $probeResult.details = $foundPath
                }

                "connectivity" {
                    try {
                        $response = Invoke-WebRequest -Uri $probe.testUrl -TimeoutSec ($probe.timeout / 1000) -UseBasicParsing -ErrorAction Stop
                        $sw.Stop()
                        $probeResult.available = $response.StatusCode -eq 200
                        $probeResult.details = "HTTP $($response.StatusCode)"
                    } catch {
                        $sw.Stop()
                        $probeResult.error = $_.Exception.Message
                    }
                }
            }
        } catch {
            $sw.Stop()
            $probeResult.error = $_.Exception.Message
        }

        $probeResult.latency = $sw.ElapsedMilliseconds

        # 更新统计
        $profile.summary.totalProbes++
        if ($probeResult.available) {
            $profile.summary.available++
            if ($probe.critical) { $profile.summary.critical.passed++ }
        } else {
            $profile.summary.unavailable++
        }
        if ($probe.critical) { $profile.summary.critical.total++ }

        $profile.probes[$probeId] = $probeResult

        # 输出探针结果
        $status = if ($probeResult.available) { "[OK]" } else { "[MISSING]" }
        $color = if ($probeResult.available) { "Green" } else { "Yellow" }
        $versionInfo = if ($probeResult.version) { " v$($probeResult.version)" } else { "" }
        Write-Host "  $status $($probe.name)$versionInfo ($($probeResult.latency)ms)" -ForegroundColor $color
    }

    return $profile
}

# ============================================================
# Step 2: 环境绑定（Environment Binding）
# ============================================================

function Invoke-EnvironmentBinding {
    param(
        [hashtable]$Manifest,
        [hashtable]$Profile
    )

    Write-Host "`n[Step 2/3] 环境绑定 — 依赖检查与修复" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor DarkGray

    $configPath = Join-Path $skillRoot "config.json"
    $config = @{}
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
    }

    $binding = @{
        capabilities = @{}
        fixScripts = @()
        configOverrides = @{}
    }

    foreach ($cap in $Manifest.capabilities) {
        $capId = $cap.id
        $capResult = @{
            id = $capId
            available = $true
            missingRequirements = @()
            selectedFallback = $null
            compensation = $null
        }

        # 检查工具依赖
        foreach ($tool in $cap.requires.tools) {
            if ($tool -eq "pwsh" -and -not $Profile.probes["pwsh"].available) {
                $capResult.available = $false
                $capResult.missingRequirements += "pwsh"
            }
            if ($tool -eq "git" -and -not $Profile.probes["git"].available) {
                $capResult.available = $false
                $capResult.missingRequirements += "git"
            }
            if ($tool -eq "dotnet-sdk" -and -not $Profile.probes["dotnet-sdk"].available) {
                $capResult.available = $false
                $capResult.missingRequirements += "dotnet-sdk"
            }
        }

        # 检查环境依赖
        foreach ($envReq in $cap.requires.env) {
            if ($envReq -eq "dotnet-sdk" -and -not $Profile.probes["dotnet-sdk"].available) {
                $capResult.available = $false
                $capResult.missingRequirements += "dotnet-sdk"
            }
            if ($envReq -eq "network" -and -not $Profile.probes["network"].available) {
                $capResult.available = $false
                $capResult.missingRequirements += "network"
            }
        }

        # 检查数据依赖
        if ($cap.requires.data) {
            foreach ($dataReq in $cap.requires.data) {
                if ($dataReq -eq "indexes") {
                    $indexDir = Join-Path $skillRoot "indexes"
                    $cacheIndexDir = Join-Path $cacheDir "indexes"
                    if (-not (Test-Path $indexDir) -and -not (Test-Path $cacheIndexDir)) {
                        $capResult.available = $false
                        $capResult.missingRequirements += "indexes"
                    }
                }
            }
        }

        # 选择回退策略
        if (-not $capResult.available -and $cap.fallbacks) {
            foreach ($fallback in $cap.fallbacks) {
                $condition = $fallback.condition
                $matched = $false

                switch ($condition) {
                    "no-pwsh" { $matched = -not $Profile.probes["pwsh"].available }
                    "no-git" { $matched = -not $Profile.probes["git"].available }
                    "no-dotnet" { $matched = -not $Profile.probes["dotnet-sdk"].available }
                    "no-network" { $matched = -not $Profile.probes["network"].available }
                    "no-ilspycmd" { $matched = -not $Profile.probes["ilspycmd"].available }
                    "no-steam" { $matched = -not $Profile.probes["steam-install"].available }
                    "no-indexes" {
                        $indexDir = Join-Path $skillRoot "indexes"
                        $cacheIndexDir = Join-Path $cacheDir "indexes"
                        $matched = -not (Test-Path $indexDir) -and -not (Test-Path $cacheIndexDir)
                    }
                    "no-source-data" {
                        $matched = -not $Profile.probes["steam-install"].available -and
                                   -not $Profile.probes["git"].available
                    }
                }

                if ($matched) {
                    $capResult.selectedFallback = $fallback.action
                    $capResult.compensation = $fallback.compensation
                    break
                }
            }
        }

        # 生成修复脚本
        if ($capResult.selectedFallback) {
            $fixScript = Generate-FixScript -Capability $cap -Fallback $capResult.selectedFallback -Profile $Profile
            if ($fixScript) {
                $binding.fixScripts += $fixScript
            }
        }

        $binding.capabilities[$capId] = $capResult

        # 输出绑定结果
        $status = if ($capResult.available) { "[OK]" } else { "[COMPENSATED]" }
        $color = if ($capResult.available) { "Green" } else { "Yellow" }
        $fallbackInfo = if ($capResult.selectedFallback) { " -> $($capResult.selectedFallback)" } else { "" }
        Write-Host "  $status $capId$fallbackInfo" -ForegroundColor $color
    }

    return $binding
}

function Generate-FixScript {
    param(
        [hashtable]$Capability,
        [string]$Fallback,
        [hashtable]$Profile
    )

    $fixScriptPath = Join-Path $fixScriptsDir "$($Capability.id)-fix.ps1"
    $content = $null

    switch ($Fallback) {
        "auto-install-ilspycmd" {
            $content = @'
# Auto-generated fix: Install ILSpy CLI
Write-Host "Installing ILSpy CLI..." -ForegroundColor Cyan
dotnet tool install -g ilspycmd
if ($LASTEXITCODE -eq 0) {
    Write-Host "ILSpy CLI installed successfully" -ForegroundColor Green
} else {
    Write-Host "Failed to install ILSpy CLI" -ForegroundColor Red
    exit 1
}
'@
        }
        "prompt-manual-path" {
            $content = @'
# Auto-generated fix: Manual path configuration
Write-Host "Please configure paths in config.json:" -ForegroundColor Yellow
Write-Host '  {"gameDll": "<path>", "ritsulibRoot": "<path>", "tutorialsRoot": "<path>"}' -ForegroundColor Gray
'@
        }
        "prompt-game-path" {
            $content = @'
# Auto-generated fix: Game path discovery
Write-Host "Could not auto-discover game installation." -ForegroundColor Yellow
Write-Host "Please provide the path to sts2.dll in config.json" -ForegroundColor Yellow
'@
        }
        "prompt-install-git" {
            $content = @'
# Auto-generated fix: Git installation
Write-Host "Git is required but not found." -ForegroundColor Yellow
Write-Host "Install Git from: https://git-scm.com/" -ForegroundColor Cyan
'@
        }
        "prompt-install-dotnet" {
            $content = @'
# Auto-generated fix: .NET SDK installation
Write-Host ".NET SDK is required but not found." -ForegroundColor Yellow
Write-Host "Install .NET SDK from: https://dotnet.microsoft.com/" -ForegroundColor Cyan
'@
        }
        "use-offline-cache" {
            $content = @'
# Auto-generated fix: Use offline cache
Write-Host "Network unavailable, using cached resources" -ForegroundColor Yellow
'@
        }
        "use-builtin-indexes" {
            $content = @'
# Auto-generated fix: Use built-in indexes
Write-Host "Using built-in indexes from indexes/ directory" -ForegroundColor Yellow
'@
        }
        "skip-decompile" {
            $content = @'
# Auto-generated fix: Skip decompilation
Write-Host ".NET SDK not available, skipping game decompilation" -ForegroundColor Yellow
Write-Host "Using built-in indexes for game content queries" -ForegroundColor Yellow
'@
        }
        "build-index-first" {
            $content = @'
# Auto-generated fix: Build indexes first
Write-Host "Indexes not found, building..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
& (Join-Path $skillRoot "scripts" "build-index.ps1")
'@
        }
        "direct-json-search" {
            $content = @'
# Auto-generated fix: Direct JSON search fallback
Write-Host "PowerShell not available, using direct JSON search" -ForegroundColor Yellow
'@
        }
        "manual-scaffold" {
            $content = @'
# Auto-generated fix: Manual project scaffolding
Write-Host "PowerShell not available for project creation." -ForegroundColor Yellow
Write-Host "Please create project manually using:" -ForegroundColor Yellow
Write-Host "  dotnet new ritsulibmod -n MyMod" -ForegroundColor Gray
'@
        }
    }

    if ($content) {
        $content | Out-File -FilePath $fixScriptPath -Encoding UTF8
        return @{
            capability = $Capability.id
            fallback = $Fallback
            script = $fixScriptPath
        }
    }

    return $null
}

# ============================================================
# Step 3: DAG 提取（DAG Extraction & Execution Plan）
# ============================================================

function Invoke-DAGExtraction {
    param(
        [hashtable]$Manifest,
        [hashtable]$Binding
    )

    Write-Host "`n[Step 3/3] DAG 提取 — 生成执行计划" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor DarkGray

    $dag = $Manifest.workflow.dag
    $entryPoints = $Manifest.workflow.entryPoints

    # 拓扑排序
    $sorted = TopologicalSort -DAG $dag

    # 识别并行组
    $parallelGroups = Identify-ParallelGroups -DAG $dag -Sorted $sorted

    # 生成执行计划
    $plan = @{
        steps = @()
        parallelGroups = @()
        fallbackSteps = @()
    }

    $stepIndex = 0
    foreach ($group in $parallelGroups) {
        $groupNodeIds = @()
        foreach ($nodeId in $group) {
            $node = $dag[$nodeId]
            $capId = $node.capability
            $capBinding = $Binding.capabilities[$capId]

            $step = @{
                index = $stepIndex
                nodeId = $nodeId
                capability = $capId
                description = $node.description
                available = $capBinding.available
                fallback = $capBinding.selectedFallback
                compensation = $capBinding.compensation
                parallel = $group.Count -gt 1
            }

            $plan.steps += $step
            $groupNodeIds += $nodeId
            $stepIndex++
        }

        if ($groupNodeIds.Count -gt 1) {
            $plan.parallelGroups += , $groupNodeIds
        }
    }

    Write-Host "  执行计划: $($plan.steps.Count) 步骤, $($plan.parallelGroups.Count) 并行组" -ForegroundColor Gray

    foreach ($step in $plan.steps) {
        $status = if ($step.available) { "[OK]" } else { "[FALLBACK]" }
        $color = if ($step.available) { "Green" } else { "Yellow" }
        $parallel = if ($step.parallel) { " (parallel)" } else { "" }
        Write-Host "    $($step.index): $status $($step.nodeId)$parallel" -ForegroundColor $color
    }

    return $plan
}

function TopologicalSort {
    param([hashtable]$DAG)

    $visited = @{}
    $sorted = [System.Collections.ArrayList]::new()

    function Visit {
        param([string]$NodeId)

        if ($visited.ContainsKey($NodeId)) { return }
        $visited[$NodeId] = $true

        $node = $DAG[$NodeId]
        if ($node.depends) {
            foreach ($dep in $node.depends) {
                Visit -NodeId $dep
            }
        }

        [void]$sorted.Add($NodeId)
    }

    foreach ($nodeId in $DAG.Keys) {
        Visit -NodeId $nodeId
    }

    return $sorted.ToArray()
}

function Identify-ParallelGroups {
    param(
        [hashtable]$DAG,
        [array]$Sorted
    )

    $groups = [System.Collections.ArrayList]::new()
    $completed = @{}
    $currentGroup = [System.Collections.ArrayList]::new()

    foreach ($nodeId in $Sorted) {
        $node = $DAG[$nodeId]

        # 检查所有依赖是否已完成
        $depsMet = $true
        if ($node.depends) {
            foreach ($dep in $node.depends) {
                if (-not $completed.ContainsKey($dep)) {
                    $depsMet = $false
                    break
                }
            }
        }

        if ($depsMet -and $node.parallel) {
            # 可以并行执行
            [void]$currentGroup.Add($nodeId)
        } else {
            # 不能并行，先保存当前组
            if ($currentGroup.Count -gt 0) {
                [void]$groups.Add($currentGroup.ToArray())
                $currentGroup = [System.Collections.ArrayList]::new()
            }

            # 添加为独立步骤
            [void]$groups.Add(@($nodeId))
        }

        $completed[$nodeId] = $true
    }

    # 保存最后一组
    if ($currentGroup.Count -gt 0) {
        [void]$groups.Add($currentGroup.ToArray())
    }

    return $groups.ToArray()
}

# ============================================================
# 主流程
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SkVM AOT 编译器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 加载清单
if (-not (Test-Path $ManifestPath)) {
    Write-Host "[ERROR] 清单文件不存在: $ManifestPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n加载清单: $ManifestPath" -ForegroundColor Gray
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json -AsHashtable

# 检查是否需要重新编译
if (-not $Force -and (Test-Path $variantPath)) {
    $existingVariant = Get-Content $variantPath -Raw | ConvertFrom-Json
    $compileTime = [DateTime]::Parse($existingVariant.timestamp)
    $age = (Get-Date) - $compileTime

    if ($age.TotalHours -lt 24) {
        Write-Host "`n[INFO] 已有编译变体（$([Math]::Floor($age.TotalHours))小时前），使用缓存" -ForegroundColor Yellow
        Write-Host "  使用 -Force 强制重新编译" -ForegroundColor Gray
        exit 0
    }
}

# Step 1: 能力画像
$profile = Invoke-CapabilityProfiling -Manifest $manifest

# Step 2: 环境绑定
$binding = Invoke-EnvironmentBinding -Manifest $manifest -Profile $profile

# Step 3: DAG 提取
$plan = Invoke-DAGExtraction -Manifest $manifest -Binding $binding

# 生成编译变体（统一格式：executionPlan.orderedSteps）
$executionPlan = @{
    orderedSteps = $plan.steps
    parallelGroups = $plan.parallelGroups
    cacheableSteps = @()
}

# 标记可缓存步骤
foreach ($step in $plan.steps) {
    $capId = $step.capability
    $cap = $manifest.capabilities | Where-Object { $_.id -eq $capId }
    if ($cap -and ($cap.cachePolicy -eq "solidify-after-5" -or $cap.cachePolicy -eq "solidify-after-3")) {
        $executionPlan.cacheableSteps += $step.nodeId
    }
}

$variant = @{
    skvmVersion = $manifest.skvmVersion
    skillVersion = $manifest.version
    timestamp = (Get-Date -Format "o")
    platform = $profile.platform
    environment = @{
        pwsh = $profile.probes["pwsh"].available
        dotnet = $profile.probes["dotnet-sdk"].available
        git = $profile.probes["git"].available
        ilspycmd = $profile.probes["ilspycmd"].available
        network = $profile.probes["network"].available
        steam = $profile.probes["steam-install"].available
    }
    capabilities = $binding.capabilities
    executionPlan = $executionPlan
    solidification = $manifest.solidification
    recompilation = $manifest.recompilation
}

# 保存编译结果
$profile | ConvertTo-Json -Depth 5 | Out-File -FilePath $profilePath -Encoding UTF8
$variant | ConvertTo-Json -Depth 5 | Out-File -FilePath $variantPath -Encoding UTF8

# 保存到变体历史
$historyDir = Join-Path $skvmDir "variant-history"
if (-not (Test-Path $historyDir)) {
    New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
}
$historyFile = Join-Path $historyDir "variant-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$variant | ConvertTo-Json -Depth 5 | Out-File -FilePath $historyFile -Encoding UTF8

# 清理旧变体历史（保留最近10个）
$historyFiles = Get-ChildItem -Path $historyDir -Filter "variant-*.json" | Sort-Object LastWriteTime -Descending
if ($historyFiles.Count -gt 10) {
    $historyFiles | Select-Object -Skip 10 | Remove-Item -Force
}

# 输出编译摘要
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  编译完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`n编译摘要：" -ForegroundColor Cyan
Write-Host "  平台: $($profile.platform)" -ForegroundColor Gray
Write-Host "  探针: $($profile.summary.available)/$($profile.summary.totalProbes) 可用" -ForegroundColor Gray
Write-Host "  关键探针: $($profile.summary.critical.passed)/$($profile.summary.critical.total) 通过" -ForegroundColor Gray
Write-Host "  修复脚本: $($binding.fixScripts.Count) 个" -ForegroundColor Gray
Write-Host "  执行步骤: $($executionPlan.orderedSteps.Count) 个" -ForegroundColor Gray

Write-Host "`n输出文件：" -ForegroundColor Cyan
Write-Host "  能力画像: $profilePath" -ForegroundColor Gray
Write-Host "  编译变体: $variantPath" -ForegroundColor Gray
Write-Host "  变体历史: $historyFile" -ForegroundColor Gray

if ($binding.fixScripts.Count -gt 0) {
    Write-Host "`n修复脚本：" -ForegroundColor Yellow
    foreach ($fix in $binding.fixScripts) {
        Write-Host "  [$($fix.capability)] $($fix.fallback)" -ForegroundColor Gray
        Write-Host "    -> $($fix.script)" -ForegroundColor DarkGray
    }
}

# 检查关键探针
if ($profile.summary.critical.passed -lt $profile.summary.critical.total) {
    Write-Host "`n[WARN] 关键探针未全部通过，部分功能可能不可用" -ForegroundColor Red
    foreach ($probe in $profile.probes.Values) {
        if ($probe.critical -and -not $probe.available) {
            Write-Host "  [CRITICAL] $($probe.name) 不可用" -ForegroundColor Red
        }
    }
}

Write-Host ""
