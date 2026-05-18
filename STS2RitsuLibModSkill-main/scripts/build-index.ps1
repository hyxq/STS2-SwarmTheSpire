<#
.SYNOPSIS
    构建 STS2 Mod 开发所需的各类索引。

.DESCRIPTION
    为 RitsuLib 文档、RitsuLib API、游戏内容、本地化、教程等建立可查询索引。
    索引只保存导航信息，不复制大段源码。

.PARAMETER RitsulibRoot
    RitsuLib 源码根目录

.PARAMETER GameSourceRoot
    反编译的游戏源码目录

.PARAMETER TutorialsRoot
    教程仓库根目录

.PARAMETER IndexDir
    索引输出目录，默认为脚本所在目录的上级目录下的 cache/indexes

.PARAMETER Force
    强制重建所有索引

.EXAMPLE
    pwsh -File build-index.ps1 -RitsulibRoot "cache/ritsulib" -GameSourceRoot "cache/decompiled/sts2"
#>

param(
    [string]$RitsulibRoot,
    [string]$GameSourceRoot,
    [string]$TutorialsRoot,
    [string]$IndexDir,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# 默认目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cacheDir = Join-Path (Split-Path -Parent $scriptDir) "cache"

if (-not $RitsulibRoot) { $RitsulibRoot = Join-Path $cacheDir "ritsulib" }
if (-not $GameSourceRoot) { $GameSourceRoot = Join-Path $cacheDir "decompiled" "sts2" }
if (-not $TutorialsRoot) { $TutorialsRoot = Join-Path $cacheDir "tutorials" }
if (-not $IndexDir) { $IndexDir = Join-Path $cacheDir "indexes" }

# 确保索引目录存在
if (-not (Test-Path $IndexDir)) {
    New-Item -ItemType Directory -Path $IndexDir -Force | Out-Null
}

# 辅助函数：检查索引是否过期
function Test-IndexStale {
    param([string]$IndexPath, [string]$SourceDir)

    if (-not (Test-Path $IndexPath)) { return $true }
    if ($Force) { return $true }

    $indexTime = (Get-Item $IndexPath).LastWriteTime
    $sourceTime = (Get-Item $SourceDir).LastWriteTime

    return $sourceTime -gt $indexTime
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
    if ($content -match "^#\s+(.+)$") {
        $title = $matches[1].Trim()
    }

    # 如果没有找到标题，尝试从 ## 标题或文件路径提取
    if (-not $title) {
        if ($content -match "^##\s+(.+)$") {
            $title = $matches[1].Trim()
        } elseif ($FallbackTitle) {
            $title = $FallbackTitle
        }
    }

    # 提取摘要（从内容中提取第一个有意义的段落）
    $lines = $content -split "`n"
    $summaryLines = @()
    $skipBlock = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # 跳过代码块
        if ($trimmed -match '^```') {
            $skipBlock = -not $skipBlock
            continue
        }
        if ($skipBlock) { continue }

        # 跳过标题行
        if ($trimmed -match '^\#{1,3}\s') { continue }

        # 跳过空行
        if ($trimmed -eq "") {
            if ($summaryLines.Count -gt 0) { break }
            continue
        }

        # 跳过引用块标记但保留内容
        if ($trimmed -match '^>\s*(.*)$') {
            $trimmed = $matches[1]
            if (-not $trimmed) { continue }
        }

        # 跳过图片和链接标记
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

# 辅助函数：从 C# 文件提取类型信息
function Extract-CSharpTypes {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $types = @()

    # 匹配 namespace
    $namespace = ""
    if ($content -match "namespace\s+([\w.]+)") {
        $namespace = $matches[1]
    }

    # 匹配类、接口、结构体、枚举
    $pattern = "(?:public|internal|private|protected)?\s*(?:static\s+)?(?:partial\s+)?(?:class|interface|struct|enum)\s+(\w+)"
    $matches = [regex]::Matches($content, $pattern)

    foreach ($match in $matches) {
        $typeName = $match.Groups[1].Value
        $fullType = if ($namespace) { "$namespace.$typeName" } else { $typeName }

        $types += @{
            name = $typeName
            fullName = $fullType
            file = $FilePath
        }
    }

    return $types
}

# 1. 构建 RitsuLib 文档索引
Write-Host "`n=== 构建 RitsuLib 文档索引 ===" -ForegroundColor Cyan
$ritsulibDocsIndex = Join-Path $IndexDir "ritsulib-docs.json"

if (Test-Path $RitsulibRoot) {
    if (Test-IndexStale -IndexPath $ritsulibDocsIndex -SourceDir $RitsulibRoot) {
        $docs = @()
        $docsDir = Join-Path $RitsulibRoot "Docs"

        if (Test-Path $docsDir) {
            $mdFiles = Get-ChildItem -Path $docsDir -Filter "*.md" -Recurse

            foreach ($file in $mdFiles) {
                $relativePath = $file.FullName.Substring($RitsulibRoot.Length + 1)
                $info = Extract-MarkdownInfo -FilePath $file.FullName

                if ($info) {
                    $docs += @{
                        path = $relativePath
                        fullPath = $file.FullName
                        title = $info.title
                        summary = $info.summary
                    }
                }
            }
        }

        $docs | ConvertTo-Json -Depth 3 | Out-File -FilePath $ritsulibDocsIndex -Encoding UTF8
        Write-Host "[INFO] RitsuLib 文档索引: $($docs.Count) 个文件" -ForegroundColor Green
    } else {
        Write-Host "[INFO] RitsuLib 文档索引已是最新" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] RitsuLib 目录不存在: $RitsulibRoot" -ForegroundColor Yellow
}

# 2. 构建 RitsuLib API 索引
Write-Host "`n=== 构建 RitsuLib API 索引 ===" -ForegroundColor Cyan
$ritsulibApiIndex = Join-Path $IndexDir "ritsulib-api.json"

if (Test-Path $RitsulibRoot) {
    if (Test-IndexStale -IndexPath $ritsulibApiIndex -SourceDir $RitsulibRoot) {
        $apiEntries = @()
        $csFiles = Get-ChildItem -Path $RitsulibRoot -Filter "*.cs" -Recurse

        foreach ($file in $csFiles) {
            $relativePath = $file.FullName.Substring($RitsulibRoot.Length + 1)
            $types = Extract-CSharpTypes -FilePath $file.FullName

            foreach ($type in $types) {
                $apiEntries += @{
                    name = $type.name
                    fullName = $type.fullName
                    file = $relativePath
                    fullPath = $file.FullName
                }
            }
        }

        $apiEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $ritsulibApiIndex -Encoding UTF8
        Write-Host "[INFO] RitsuLib API 索引: $($apiEntries.Count) 个类型" -ForegroundColor Green
    } else {
        Write-Host "[INFO] RitsuLib API 索引已是最新" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] RitsuLib 目录不存在: $RitsulibRoot" -ForegroundColor Yellow
}

# 3. 构建游戏内容索引
Write-Host "`n=== 构建游戏内容索引 ===" -ForegroundColor Cyan
$sts2ContentIndex = Join-Path $IndexDir "sts2-content.json"

if (Test-Path $GameSourceRoot) {
    if (Test-IndexStale -IndexPath $sts2ContentIndex -SourceDir $GameSourceRoot) {
        $contentEntries = @()
        $csFiles = Get-ChildItem -Path $GameSourceRoot -Filter "*.cs" -Recurse

        foreach ($file in $csFiles) {
            $relativePath = $file.FullName.Substring($GameSourceRoot.Length + 1)
            $types = Extract-CSharpTypes -FilePath $file.FullName

            foreach ($type in $types) {
                # 推测内容类型
                $contentType = "unknown"
                $nameLower = $type.name.ToLower()

                if ($nameLower -match "card") { $contentType = "card" }
                elseif ($nameLower -match "relic") { $contentType = "relic" }
                elseif ($nameLower -match "character|player") { $contentType = "character" }
                elseif ($nameLower -match "event") { $contentType = "event" }
                elseif ($nameLower -match "monster|enemy|boss") { $contentType = "monster" }
                elseif ($nameLower -match "keyword") { $contentType = "keyword" }
                elseif ($nameLower -match "potion") { $contentType = "potion" }
                elseif ($nameLower -match "power|buff") { $contentType = "power" }

                $contentEntries += @{
                    name = $type.name
                    fullName = $type.fullName
                    file = $relativePath
                    fullPath = $file.FullName
                    contentType = $contentType
                }
            }
        }

        $contentEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $sts2ContentIndex -Encoding UTF8
        Write-Host "[INFO] 游戏内容索引: $($contentEntries.Count) 个类型" -ForegroundColor Green
    } else {
        Write-Host "[INFO] 游戏内容索引已是最新" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] 游戏源码目录不存在: $GameSourceRoot" -ForegroundColor Yellow
}

# 4. 构建本地化索引
Write-Host "`n=== 构建本地化索引 ===" -ForegroundColor Cyan
$sts2LocalIndex = Join-Path $IndexDir "sts2-localization.json"

if (Test-Path $GameSourceRoot) {
    if (Test-IndexStale -IndexPath $sts2LocalIndex -SourceDir $GameSourceRoot) {
        $localEntries = @()

        # 查找本地化文件（通常在 Resources 或 Localization 目录）
        $localFiles = Get-ChildItem -Path $GameSourceRoot -Filter "*.json" -Recurse |
            Where-Object { $_.FullName -match "local|i18n|lang|resource" }

        foreach ($file in $localFiles) {
            $relativePath = $file.FullName.Substring($GameSourceRoot.Length + 1)
            try {
                $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
                # 提取键值对
                $content.PSObject.Properties | ForEach-Object {
                    $localEntries += @{
                        key = $_.Name
                        value = $_.Value.Substring(0, [Math]::Min(100, $_.Value.Length))
                        file = $relativePath
                    }
                }
            } catch {
                # 忽略解析错误
            }
        }

        $localEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $sts2LocalIndex -Encoding UTF8
        Write-Host "[INFO] 本地化索引: $($localEntries.Count) 个条目" -ForegroundColor Green
    } else {
        Write-Host "[INFO] 本地化索引已是最新" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] 游戏源码目录不存在: $GameSourceRoot" -ForegroundColor Yellow
}

# 5. 构建教程索引
Write-Host "`n=== 构建教程索引 ===" -ForegroundColor Cyan
$tutorialsIndex = Join-Path $IndexDir "tutorials.json"

if (Test-Path $TutorialsRoot) {
    if (Test-IndexStale -IndexPath $tutorialsIndex -SourceDir $TutorialsRoot) {
        $tutorials = @()

        # 主要读取 RitsuLib 目录
        $ritsulibTutorialsDir = Join-Path $TutorialsRoot "RitsuLib"
        if (-not (Test-Path $ritsulibTutorialsDir)) {
            $ritsulibTutorialsDir = $TutorialsRoot
        }

        $mdFiles = Get-ChildItem -Path $ritsulibTutorialsDir -Filter "*.md" -Recurse

        foreach ($file in $mdFiles) {
            $relativePath = $file.FullName.Substring($TutorialsRoot.Length + 1)

            # 从目录名提取备选标题（例如 "01 - 添加卡牌" -> "添加卡牌"）
            $fallbackTitle = ""
            $dirName = $file.Directory.Name
            if ($dirName -match "^\d+\s*[-—]\s*(.+)$") {
                $fallbackTitle = $matches[1].Trim()
            } elseif ($file.Name -eq "README.md") {
                $fallbackTitle = $dirName
            }

            $info = Extract-MarkdownInfo -FilePath $file.FullName -FallbackTitle $fallbackTitle

            if ($info) {
                # 推测教程主题
                $topic = "general"
                $titleLower = $info.title.ToLower()
                $pathLower = $relativePath.ToLower()

                if ($titleLower -match "卡牌|card") { $topic = "card" }
                elseif ($titleLower -match "遗物|relic") { $topic = "relic" }
                elseif ($titleLower -match "人物|character") { $topic = "character" }
                elseif ($titleLower -match "事件|event") { $topic = "event" }
                elseif ($titleLower -match "怪物|monster") { $topic = "monster" }
                elseif ($titleLower -match "能力|power") { $topic = "power" }
                elseif ($titleLower -match "药水|potion") { $topic = "potion" }
                elseif ($titleLower -match "补丁|patch|harmony") { $topic = "patch" }
                elseif ($titleLower -match "配置|config") { $topic = "config" }
                elseif ($titleLower -match "本地化|localization") { $topic = "localization" }
                elseif ($titleLower -match "存档|save") { $topic = "save" }
                elseif ($titleLower -match "生命周期|lifecycle") { $topic = "lifecycle" }

                $tutorials += @{
                    path = $relativePath
                    fullPath = $file.FullName
                    title = $info.title
                    summary = $info.summary
                    topic = $topic
                }
            }
        }

        $tutorials | ConvertTo-Json -Depth 3 | Out-File -FilePath $tutorialsIndex -Encoding UTF8
        Write-Host "[INFO] 教程索引: $($tutorials.Count) 个文件" -ForegroundColor Green
    } else {
        Write-Host "[INFO] 教程索引已是最新" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] 教程目录不存在: $TutorialsRoot" -ForegroundColor Yellow
}

Write-Host "`n=== 索引构建完成 ===" -ForegroundColor Green
