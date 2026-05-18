<#
.SYNOPSIS
    构建内置索引（提交到项目中，跨平台）。

.DESCRIPTION
    生成 RitsuLib、教程和游戏内容的内置索引文件。
    这些索引会被提交到项目中，用户无需运行此脚本。

.PARAMETER GameSourceRoot
    游戏源码目录（默认自动发现）

.PARAMETER LocalizationDir
    本地化目录（默认自动发现）

.PARAMETER RitsulibRoot
    RitsuLib 源码目录

.PARAMETER TutorialsRoot
    教程目录

.EXAMPLE
    pwsh -File build-builtin-indexes.ps1
    pwsh -File build-builtin-indexes.ps1 -GameSourceRoot ~/Games/STS2/src
#>

param(
    [string]$GameSourceRoot,
    [string]$LocalizationDir,
    [string]$RitsulibRoot,
    [string]$TutorialsRoot,
    [string]$IndexDir
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptDir
$cacheDir = Join-Path $skillRoot "cache"
$globalConfigPath = Join-Path $skillRoot "config.json"

# 读取全局配置
$globalConfig = $null
if (Test-Path $globalConfigPath) {
    $globalConfig = Get-Content $globalConfigPath | ConvertFrom-Json
}

# 应用全局配置（参数优先）
if (-not $RitsulibRoot) {
    if ($globalConfig -and $globalConfig.ritsulibRoot -and $globalConfig.ritsulibRoot -ne "") {
        $RitsulibRoot = $globalConfig.ritsulibRoot
    } else {
        $RitsulibRoot = Join-Path $cacheDir "ritsulib"
    }
}
if (-not $TutorialsRoot) {
    if ($globalConfig -and $globalConfig.tutorialsRoot -and $globalConfig.tutorialsRoot -ne "") {
        $TutorialsRoot = $globalConfig.tutorialsRoot
    } else {
        $TutorialsRoot = Join-Path $cacheDir "tutorials"
    }
}
if (-not $IndexDir) { $IndexDir = Join-Path $skillRoot "indexes" }

# 获取本地化语言配置
$localizationLang = "zhs"
if ($globalConfig -and $globalConfig.localizationLang) {
    $localizationLang = $globalConfig.localizationLang
}

# 确保索引目录存在
if (-not (Test-Path $IndexDir)) {
    New-Item -ItemType Directory -Path $IndexDir -Force | Out-Null
}

# 自动发现游戏目录（跨平台）
function Find-GameDirectory {
    # 1. 常见的用户自定义位置
    $homeDir = if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
    $desktopPath = Join-Path $homeDir "Desktop"
    $documentsPath = if ($IsWindows) {
        [Environment]::GetFolderPath("MyDocuments")
    } else {
        Join-Path $homeDir "Documents"
    }

    $commonPaths = @(
        (Join-Path $desktopPath "Slay the Spire 2"),
        (Join-Path $desktopPath "STS2"),
        (Join-Path $documentsPath "Slay the Spire 2"),
        (Join-Path $documentsPath "STS2")
    )

    # Linux/Unix 额外路径
    if (-not $IsWindows) {
        $commonPaths += @(
            (Join-Path $homeDir "Games/Slay the Spire 2"),
            (Join-Path $homeDir "Games/STS2"),
            "/opt/Slay the Spire 2"
        )
    }

    foreach ($path in $commonPaths) {
        if ($path -and (Test-Path $path)) {
            $srcPath = Join-Path $path "src"
            if (Test-Path $srcPath) {
                return $path
            }
        }
    }

    # 2. Steam 安装目录
    $steamPath = $null

    if ($IsWindows) {
        $regPaths = @(
            "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
            "HKLM:\SOFTWARE\Valve\Steam"
        )
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                $installPath = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).InstallPath
                if ($installPath -and (Test-Path $installPath)) {
                    $steamPath = $installPath
                    break
                }
            }
        }
        if (-not $steamPath) {
            $steamPath = "${env:ProgramFiles(x86)}\Steam"
        }
    } elseif ($IsMacOS) {
        $steamPath = "$env:HOME/Library/Application Support/Steam"
    } else {
        $steamPath = "$env:HOME/.steam/steam"
    }

    if (-not $steamPath -or -not (Test-Path $steamPath)) { return $null }

    # 解析 libraryfolders.vdf
    $vdfPath = Join-Path $steamPath "steamapps/libraryfolders.vdf"
    $libraryPaths = @($steamPath)

    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath -Raw
        $vdfMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($match in $vdfMatches) {
            $libPath = $match.Groups[1].Value
            if ($IsWindows) {
                $libPath = $libPath -replace '\\\\', '\'
            }
            if (Test-Path $libPath) {
                $libraryPaths += $libPath
            }
        }
    }

    # 查找 STS2
    foreach ($libPath in $libraryPaths) {
        $gamePath = Join-Path $libPath "steamapps/common/Slay the Spire 2"
        if (Test-Path $gamePath) {
            return $gamePath
        }
    }

    return $null
}

# 如果未指定游戏源码目录，自动发现
if (-not $GameSourceRoot) {
    Write-Host "[INFO] 自动发现游戏目录..." -ForegroundColor Cyan
    $gameDir = Find-GameDirectory

    if ($gameDir) {
        $GameSourceRoot = Join-Path $gameDir "src"
        Write-Host "[INFO] 找到游戏目录: $gameDir" -ForegroundColor Green
    } else {
        Write-Host "[WARN] 未找到游戏目录，请使用 -GameSourceRoot 参数指定" -ForegroundColor Yellow
    }
}

# 如果未指定本地化目录，从游戏目录推断
if (-not $LocalizationDir -and $GameSourceRoot) {
    $gameDir = Split-Path -Parent $GameSourceRoot

    # 查找本地化目录（支持多种语言）
    $localizationBase = Join-Path $gameDir "localization"
    if (Test-Path $localizationBase) {
        # 优先使用配置的语言，其次默认语言
        $langDir = Join-Path $localizationBase $localizationLang
        if (Test-Path $langDir) {
            $LocalizationDir = $langDir
        } else {
            # 回退到英文
            $engDir = Join-Path $localizationBase "eng"
            if (Test-Path $engDir) {
                $LocalizationDir = $engDir
            } else {
                # 使用第一个目录
                $firstDir = Get-ChildItem -Path $localizationBase -Directory | Select-Object -First 1
                if ($firstDir) {
                    $LocalizationDir = $firstDir.FullName
                }
            }
        }
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  构建内置索引" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "路径配置：" -ForegroundColor Gray
Write-Host "  平台:       $(if ($IsWindows) {'Windows'} elseif ($IsMacOS) {'macOS'} else {'Linux'})" -ForegroundColor Gray
Write-Host "  游戏源码:   $($GameSourceRoot ?? '未找到')" -ForegroundColor Gray
Write-Host "  本地化:     $($LocalizationDir ?? '未找到')" -ForegroundColor Gray
Write-Host "  RitsuLib:   $RitsulibRoot" -ForegroundColor Gray
Write-Host "  教程:       $TutorialsRoot" -ForegroundColor Gray
Write-Host ""

# 辅助函数：从 C# 文件提取类型信息
function Extract-CSharpTypes {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $types = @()

    # 匹配 namespace
    $namespace = ""
    if ($content -match 'namespace\s+([\w.]+)') {
        $namespace = $matches[1]
    }

    # 匹配类、接口、结构体、枚举
    $pattern = '(?:public|internal|private|protected)?\s*(?:static\s+)?(?:partial\s+)?(?:class|interface|struct|enum)\s+(\w+)'
    $regexMatches = [regex]::Matches($content, $pattern)

    foreach ($match in $regexMatches) {
        $typeName = $match.Groups[1].Value
        $fullType = if ($namespace) { "$namespace.$typeName" } else { $typeName }

        # 推测内容类型
        $contentType = "unknown"
        $nameLower = $typeName.ToLower()

        if ($nameLower -match "card") { $contentType = "card" }
        elseif ($nameLower -match "relic") { $contentType = "relic" }
        elseif ($nameLower -match "character|player") { $contentType = "character" }
        elseif ($nameLower -match "event") { $contentType = "event" }
        elseif ($nameLower -match "monster|enemy|boss") { $contentType = "monster" }
        elseif ($nameLower -match "keyword") { $contentType = "keyword" }
        elseif ($nameLower -match "potion") { $contentType = "potion" }
        elseif ($nameLower -match "power|buff") { $contentType = "power" }
        elseif ($nameLower -match "ancient") { $contentType = "ancient" }
        elseif ($nameLower -match "enchant") { $contentType = "enchantment" }
        elseif ($nameLower -match "orb") { $contentType = "orb" }
        elseif ($nameLower -match "timeline") { $contentType = "timeline" }

        $types += @{
            name = $typeName
            fullName = $fullType
            contentType = $contentType
        }
    }

    return $types
}

# 辅助函数：从 Markdown 文件提取标题和摘要
function Extract-MarkdownInfo {
    param(
        [string]$FilePath,
        [string]$FallbackTitle = ""
    )

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $title = ""
    $summary = ""

    # 提取标题（第一个 # 开头的行）
    if ($content -match '^#\s+(.+)$') {
        $title = $matches[1].Trim()
    }

    # 如果没有找到标题，尝试从 ## 标题或文件路径提取
    if (-not $title) {
        if ($content -match '^##\s+(.+)$') {
            $title = $matches[1].Trim()
        } elseif ($FallbackTitle) {
            $title = $FallbackTitle
        }
    }

    # 提取摘要
    $lines = $content -split "`n"
    $summaryLines = @()
    $skipBlock = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^```') {
            $skipBlock = -not $skipBlock
            continue
        }
        if ($skipBlock) { continue }
        if ($trimmed -match '^\#{1,3}\s') { continue }
        if ($trimmed -eq "") {
            if ($summaryLines.Count -gt 0) { break }
            continue
        }
        if ($trimmed -match '^>\s*(.*)$') {
            $trimmed = $matches[1]
            if (-not $trimmed) { continue }
        }
        if ($trimmed -match '^!\[') { continue }
        $summaryLines += $trimmed
    }

    $summaryText = ($summaryLines -join " ")
    if ($summaryText.Length -gt 200) {
        $summary = $summaryText.Substring(0, 200) + "..."
    } else {
        $summary = $summaryText
    }

    return @{
        title = $title
        summary = $summary
    }
}

# 1. 构建游戏内容索引
Write-Host "[1/3] 构建游戏内容索引..." -ForegroundColor Yellow
$sts2ContentIndex = Join-Path $IndexDir "sts2-content.json"

if ($GameSourceRoot -and (Test-Path $GameSourceRoot)) {
    $contentEntries = @()
    $csFiles = Get-ChildItem -Path $GameSourceRoot -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  找到 $($csFiles.Count) 个 C# 文件" -ForegroundColor Gray

    foreach ($file in $csFiles) {
        $relativePath = $file.FullName.Substring($GameSourceRoot.Length + 1)
        $types = Extract-CSharpTypes -FilePath $file.FullName

        foreach ($type in $types) {
            $contentEntries += @{
                name = $type.name
                fullName = $type.fullName
                file = $relativePath
                contentType = $type.contentType
            }
        }
    }

    $contentEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $sts2ContentIndex -Encoding UTF8
    Write-Host "  游戏内容索引: $($contentEntries.Count) 个类型" -ForegroundColor Green
} else {
    Write-Host "  [WARN] 游戏源码目录不存在，跳过" -ForegroundColor Yellow
}

# 2. 构建本地化索引
Write-Host "`n[2/3] 构建本地化索引..." -ForegroundColor Yellow
$sts2LocalIndex = Join-Path $IndexDir "sts2-localization.json"

if ($LocalizationDir -and (Test-Path $LocalizationDir)) {
    $localEntries = @()
    $jsonFiles = Get-ChildItem -Path $LocalizationDir -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  找到 $($jsonFiles.Count) 个本地化文件" -ForegroundColor Gray

    foreach ($file in $jsonFiles) {
        $relativePath = $file.FullName.Substring($LocalizationDir.Length + 1)
        try {
            $jsonContent = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $jsonContent.PSObject.Properties | ForEach-Object {
                $value = if ($_.Value -is [string]) { $_.Value } else { $_.Value.ToString() }
                $localEntries += @{
                    key = $_.Name
                    value = $value.Substring(0, [Math]::Min(100, $value.Length))
                    file = $relativePath
                }
            }
        } catch {
            # 忽略解析错误
        }
    }

    $localEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $sts2LocalIndex -Encoding UTF8
    Write-Host "  本地化索引: $($localEntries.Count) 个条目" -ForegroundColor Green
} else {
    Write-Host "  [WARN] 本地化目录不存在，跳过" -ForegroundColor Yellow
}

# 3. 复制 RitsuLib 和教程索引
Write-Host "`n[3/3] 复制 RitsuLib 和教程索引..." -ForegroundColor Yellow

$cacheIndexes = Join-Path $cacheDir "indexes"
$builtinFiles = @("ritsulib-api.json", "ritsulib-docs.json", "tutorials.json")

foreach ($file in $builtinFiles) {
    $src = Join-Path $cacheIndexes $file
    $dst = Join-Path $IndexDir $file

    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  复制: $file" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] 缓存中不存在: $file，请先运行 init-skill.ps1" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  内置索引构建完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "索引目录: $IndexDir" -ForegroundColor Gray
