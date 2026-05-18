<#
.SYNOPSIS
    发现 STS2 Mod 开发所需的各个根目录路径（跨平台）。

.DESCRIPTION
    按优先级查找：
    1. Skill 全局配置 config.json
    2. 缓存目录中已有的资源
    3. 自动发现 Steam 安装目录
    4. 自动拉取 RitsuLib 和教程仓库（如需要）
    5. 将发现结果保存到全局配置

.PARAMETER OutputFormat
    输出格式：json 或 text（默认 json）

.EXAMPLE
    pwsh -File discover-roots.ps1
    pwsh -File discover-roots.ps1 -OutputFormat text
#>

param(
    [ValidateSet("json", "text")]
    [string]$OutputFormat = "json"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$cacheDir = Join-Path $skillRoot "cache"
$globalConfigPath = Join-Path $skillRoot "config.json"

$result = @{
    gameDll = $null
    ritsulibRoot = $null
    gameSourceRoot = $null
    tutorialsRoot = $null
    localizationLang = "zhs"
    sources = @{}
    platform = if ($IsWindows) { "windows" } elseif ($IsMacOS) { "macos" } else { "linux" }
}

# 保存配置到全局配置文件
function Save-GlobalConfig {
    param(
        [string]$GameDll,
        [string]$GameSourceRoot,
        [string]$RitsulibRoot,
        [string]$TutorialsRoot,
        [string]$LocalizationLang
    )

    # 读取现有配置
    $config = @{}
    if (Test-Path $globalConfigPath) {
        $config = Get-Content $globalConfigPath -Raw | ConvertFrom-Json -AsHashtable
    }

    # 更新配置（只更新非空值）
    if ($GameDll) { $config.gameDll = $GameDll }
    if ($GameSourceRoot) { $config.gameSourceRoot = $GameSourceRoot }
    if ($RitsulibRoot) { $config.ritsulibRoot = $RitsulibRoot }
    if ($TutorialsRoot) { $config.tutorialsRoot = $TutorialsRoot }
    if ($LocalizationLang) { $config.localizationLang = $LocalizationLang }

    # 保存配置
    $config | ConvertTo-Json -Depth 3 | Out-File -FilePath $globalConfigPath -Encoding UTF8
    Write-Host "[INFO] 已保存发现结果到: $globalConfigPath" -ForegroundColor Green
}

# 1. 检查 Skill 全局配置
if (Test-Path $globalConfigPath) {
    Write-Host "[INFO] 读取全局配置: $globalConfigPath" -ForegroundColor Cyan
    $globalConfig = Get-Content $globalConfigPath | ConvertFrom-Json

    if ($globalConfig.gameDll -and $globalConfig.gameDll -ne "" -and (Test-Path $globalConfig.gameDll)) {
        $result.gameDll = $globalConfig.gameDll
        $result.sources.gameDll = "config"
    }
    if ($globalConfig.gameSourceRoot -and $globalConfig.gameSourceRoot -ne "" -and (Test-Path $globalConfig.gameSourceRoot)) {
        $result.gameSourceRoot = $globalConfig.gameSourceRoot
        $result.sources.gameSourceRoot = "config"
    }
    if ($globalConfig.ritsulibRoot -and $globalConfig.ritsulibRoot -ne "" -and (Test-Path $globalConfig.ritsulibRoot)) {
        $result.ritsulibRoot = $globalConfig.ritsulibRoot
        $result.sources.ritsulibRoot = "config"
    }
    if ($globalConfig.tutorialsRoot -and $globalConfig.tutorialsRoot -ne "" -and (Test-Path $globalConfig.tutorialsRoot)) {
        $result.tutorialsRoot = $globalConfig.tutorialsRoot
        $result.sources.tutorialsRoot = "config"
    }
    if ($globalConfig.localizationLang) {
        $result.localizationLang = $globalConfig.localizationLang
    }
}

# 2. 自动发现 Steam 安装目录（跨平台）
function Find-SteamPath {
    # Windows: 从注册表读取
    if ($IsWindows) {
        $regPaths = @(
            "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
            "HKLM:\SOFTWARE\Valve\Steam"
        )

        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                $installPath = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).InstallPath
                if ($installPath -and (Test-Path $installPath)) {
                    return $installPath
                }
            }
        }

        # Windows 默认路径
        $defaultPaths = @(
            "${env:ProgramFiles(x86)}\Steam",
            "$env:ProgramFiles\Steam",
            "D:\Steam",
            "D:\SteamLibrary"
        )
    }
    # macOS
    elseif ($IsMacOS) {
        $defaultPaths = @(
            "$env:HOME/Library/Application Support/Steam"
        )
    }
    # Linux
    else {
        $defaultPaths = @(
            "$env:HOME/.steam/steam",
            "$env:HOME/.local/share/Steam",
            "$env:HOME/.steam"
        )
    }

    foreach ($path in $defaultPaths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    return $null
}

function Find-GameDll {
    param([string]$SteamPath)

    if (-not $SteamPath) { return $null }

    # 解析 libraryfolders.vdf 查找所有库路径
    $vdfPath = Join-Path $SteamPath "steamapps/libraryfolders.vdf"
    $libraryPaths = @($SteamPath)

    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath -Raw
        # 简单解析 VDF 格式
        $vdfMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($match in $vdfMatches) {
            $libPath = $match.Groups[1].Value
            # Windows 路径转换
            if ($IsWindows) {
                $libPath = $libPath -replace '\\\\', '\'
            }
            if (Test-Path $libPath) {
                $libraryPaths += $libPath
            }
        }
    }

    # 平台特定的 DLL 路径
    if ($IsWindows) {
        $dllRelativePath = "steamapps/common/Slay the Spire 2/data_sts2_windows_x86_64/sts2.dll"
    } elseif ($IsMacOS) {
        $dllRelativePath = "steamapps/common/Slay the Spire 2/Slay the Spire 2.app/Contents/Resources/data_sts2_macos_x86_64/sts2.dylib"
    } else {
        $dllRelativePath = "steamapps/common/Slay the Spire 2/data_sts2_linux_x86_64/libsts2.so"
    }

    # 在所有库中查找 STS2
    foreach ($libPath in $libraryPaths) {
        $gamePath = Join-Path $libPath "steamapps/common/Slay the Spire 2"
        if (Test-Path $gamePath) {
            # 查找 DLL 或源码目录
            $srcPath = Join-Path $gamePath "src"
            if (Test-Path $srcPath) {
                return @{
                    gamePath = $gamePath
                    hasSource = $true
                }
            }

            $dllPath = Join-Path $libPath $dllRelativePath
            if (Test-Path $dllPath) {
                return @{
                    gamePath = $gamePath
                    dllPath = $dllPath
                    hasSource = $false
                }
            }
        }
    }

    return $null
}

# 如果 gameDll 未找到，尝试自动发现
$needSave = $false
if (-not $result.gameDll -and -not $result.gameSourceRoot) {
    Write-Host "[INFO] 尝试自动发现 Steam 安装目录..." -ForegroundColor Cyan
    $steamPath = Find-SteamPath

    if ($steamPath) {
        Write-Host "[INFO] 找到 Steam 安装目录: $steamPath" -ForegroundColor Green
        $found = Find-GameDll -SteamPath $steamPath

        if ($found) {
            Write-Host "[INFO] 找到游戏目录: $($found.gamePath)" -ForegroundColor Green
            if ($found.hasSource) {
                $result.gameSourceRoot = Join-Path $found.gamePath "src"
                $result.sources.gameSourceRoot = "auto-discover"
                $needSave = $true
            }
            if ($found.dllPath) {
                $result.gameDll = $found.dllPath
                $result.sources.gameDll = "auto-discover"
                $needSave = $true
            }
        }
    }
}

# 3. 检查缓存中的 RitsuLib
$ritsulibCache = Join-Path $cacheDir "ritsulib"
if (-not $result.ritsulibRoot -and (Test-Path $ritsulibCache)) {
    $result.ritsulibRoot = $ritsulibCache
    $result.sources.ritsulibRoot = "cache"
}

# 4. 检查缓存中的教程
$tutorialsCache = Join-Path $cacheDir "tutorials"
if (-not $result.tutorialsRoot -and (Test-Path $tutorialsCache)) {
    $result.tutorialsRoot = $tutorialsCache
    $result.sources.tutorialsRoot = "cache"
}

# 5. 检查缓存中的反编译源码
$decompileCache = Join-Path $cacheDir "decompiled" "sts2"
if (-not $result.gameSourceRoot -and (Test-Path $decompileCache)) {
    $files = Get-ChildItem -Path $decompileCache -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
        $result.gameSourceRoot = $decompileCache
        $result.sources.gameSourceRoot = "cache"
    }
}

# 6. 保存发现结果到全局配置
if ($needSave) {
    Save-GlobalConfig -GameDll $result.gameDll -GameSourceRoot $result.gameSourceRoot -LocalizationLang $result.localizationLang
}

# 输出结果
if ($OutputFormat -eq "json") {
    $result | ConvertTo-Json -Depth 3
} else {
    Write-Host "`n=== 发现的路径 ===" -ForegroundColor Yellow
    Write-Host "平台:           $($result.platform)"
    Write-Host "Game DLL:       $($result.gameDll ?? '未找到') [$($result.sources.gameDll ?? 'N/A')]"
    Write-Host "Game Source:     $($result.gameSourceRoot ?? '未找到') [$($result.sources.gameSourceRoot ?? 'N/A')]"
    Write-Host "RitsuLib Root:  $($result.ritsulibRoot ?? '未找到') [$($result.sources.ritsulibRoot ?? 'N/A')]"
    Write-Host "Tutorials:      $($result.tutorialsRoot ?? '未找到') [$($result.sources.tutorialsRoot ?? 'N/A')]"
}

# 返回缺失项供调用方处理
$missing = @()
if (-not $result.gameDll -and -not $result.gameSourceRoot) { $missing += "gameDll/gameSource" }

if ($missing.Count -gt 0 -and $OutputFormat -eq "text") {
    Write-Host "`n[WARN] 缺失以下路径: $($missing -join ', ')" -ForegroundColor Yellow
    Write-Host "[INFO] RitsuLib 和教程将在需要时自动拉取" -ForegroundColor Cyan
}
