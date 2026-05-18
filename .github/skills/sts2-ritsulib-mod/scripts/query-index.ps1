<#
.SYNOPSIS
    查询 STS2 Mod 开发索引。

.DESCRIPTION
    按类型、名称、关键词查询原版内容、RitsuLib API、本地化和教程。

.PARAMETER Type
    查询类型：card, relic, character, event, monster, keyword, power, potion,
              ritsulib-api, ritsulib-docs, localization, tutorial

.PARAMETER Name
    按名称查询（支持模糊匹配）

.PARAMETER Keyword
    按关键词搜索

.PARAMETER Key
    按本地化键查询

.PARAMETER IndexDir
    索引目录，默认为脚本所在目录的上级目录下的 cache/indexes

.PARAMETER OutputFormat
    输出格式：json 或 text（默认 text）

.PARAMETER Limit
    最大返回结果数，默认 20

.EXAMPLE
    pwsh -File query-index.ps1 -Type card -Name "Abrasive"
    pwsh -File query-index.ps1 -Type ritsulib-api -Keyword "AddCard"
    pwsh -File query-index.ps1 -Type localization -Key "card_strike_name"
    pwsh -File query-index.ps1 -Type tutorial -Keyword "卡牌"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("card", "relic", "character", "event", "monster", "keyword", "power", "potion",
                 "ritsulib-api", "ritsulib-docs", "localization", "tutorial")]
    [string]$Type,
    [string]$Name,
    [string]$Keyword,
    [string]$Key,
    [string]$IndexDir,
    [ValidateSet("json", "text")]
    [string]$OutputFormat = "text",
    [int]$Limit = 20
)

$ErrorActionPreference = "Stop"

# 默认索引目录（优先使用内置索引）
if (-not $IndexDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $skillRoot = Split-Path -Parent $scriptDir
    $builtinIndexDir = Join-Path $skillRoot "indexes"
    $cacheIndexDir = Join-Path $skillRoot "cache" "indexes"

    # 优先使用内置索引
    if (Test-Path $builtinIndexDir) {
        $IndexDir = $builtinIndexDir
    } else {
        $IndexDir = $cacheIndexDir
    }
}

# 加载索引
function Load-Index {
    param([string]$IndexPath)

    if (-not (Test-Path $IndexPath)) {
        return @()
    }

    $content = Get-Content $IndexPath -Raw
    if (-not $content) { return @() }

    return $content | ConvertFrom-Json
}

# 模糊匹配
function Test-FuzzyMatch {
    param([string]$text, [string]$pattern)

    if (-not $pattern) { return $true }
    if (-not $text) { return $false }

    return $text -like "*$pattern*"
}

# 根据查询类型选择索引文件和过滤逻辑
$results = @()

switch ($Type) {
    { $_ -in @("card", "relic", "character", "event", "monster", "keyword", "power", "potion") } {
        $indexFile = Join-Path $IndexDir "sts2-content.json"
        $data = Load-Index -IndexPath $indexFile

        $contentTypeMap = @{
            "card" = "card"
            "relic" = "relic"
            "character" = "character"
            "event" = "event"
            "monster" = "monster"
            "keyword" = "keyword"
            "power" = "power"
            "potion" = "potion"
        }

        $targetType = $contentTypeMap[$Type]

        $results = $data | Where-Object {
            ($_.contentType -eq $targetType) -and
            (Test-FuzzyMatch -text $_.name -pattern $Name) -and
            (Test-FuzzyMatch -text $_.name -pattern $Keyword)
        } | Select-Object -First $Limit
    }

    "ritsulib-api" {
        $indexFile = Join-Path $IndexDir "ritsulib-api.json"
        $data = Load-Index -IndexPath $indexFile

        $results = $data | Where-Object {
            (Test-FuzzyMatch -text $_.name -pattern $Name) -or
            (Test-FuzzyMatch -text $_.fullName -pattern $Keyword)
        } | Select-Object -First $Limit
    }

    "ritsulib-docs" {
        $indexFile = Join-Path $IndexDir "ritsulib-docs.json"
        $data = Load-Index -IndexPath $indexFile

        $results = $data | Where-Object {
            (Test-FuzzyMatch -text $_.title -pattern $Name) -or
            (Test-FuzzyMatch -text $_.title -pattern $Keyword) -or
            (Test-FuzzyMatch -text $_.summary -pattern $Keyword)
        } | Select-Object -First $Limit
    }

    "localization" {
        $indexFile = Join-Path $IndexDir "sts2-localization.json"
        $data = Load-Index -IndexPath $indexFile

        if ($Key) {
            $results = $data | Where-Object {
                $_.key -eq $Key -or $_.key -like "*$Key*"
            } | Select-Object -First $Limit
        } else {
            $results = $data | Where-Object {
                (Test-FuzzyMatch -text $_.key -pattern $Keyword) -or
                (Test-FuzzyMatch -text $_.value -pattern $Keyword)
            } | Select-Object -First $Limit
        }
    }

    "tutorial" {
        $indexFile = Join-Path $IndexDir "tutorials.json"
        $data = Load-Index -IndexPath $indexFile

        $results = $data | Where-Object {
            (Test-FuzzyMatch -text $_.title -pattern $Name) -or
            (Test-FuzzyMatch -text $_.title -pattern $Keyword) -or
            (Test-FuzzyMatch -text $_.summary -pattern $Keyword) -or
            (Test-FuzzyMatch -text $_.topic -pattern $Keyword)
        } | Select-Object -First $Limit
    }
}

# 输出结果
if ($OutputFormat -eq "json") {
    $results | ConvertTo-Json -Depth 3
} else {
    if ($results.Count -eq 0) {
        Write-Host "[INFO] 未找到匹配的结果" -ForegroundColor Yellow
        return
    }

    Write-Host "`n=== 查询结果 ($Type) ===" -ForegroundColor Cyan
    Write-Host "找到 $($results.Count) 个结果：`n" -ForegroundColor Gray

    foreach ($result in $results) {
        switch ($Type) {
            { $_ -in @("card", "relic", "character", "event", "monster", "keyword", "power", "potion") } {
                Write-Host "  [$($result.contentType)] $($result.name)" -ForegroundColor White
                Write-Host "    文件: $($result.file)" -ForegroundColor Gray
            }

            "ritsulib-api" {
                Write-Host "  $($result.fullName)" -ForegroundColor White
                Write-Host "    文件: $($result.file)" -ForegroundColor Gray
            }

            "ritsulib-docs" {
                Write-Host "  $($result.title)" -ForegroundColor White
                Write-Host "    路径: $($result.path)" -ForegroundColor Gray
                if ($result.summary) {
                    Write-Host "    摘要: $($result.summary.Substring(0, [Math]::Min(80, $result.summary.Length)))..." -ForegroundColor Gray
                }
            }

            "localization" {
                Write-Host "  $($result.key)" -ForegroundColor White
                Write-Host "    值: $($result.value)" -ForegroundColor Gray
                Write-Host "    文件: $($result.file)" -ForegroundColor Gray
            }

            "tutorial" {
                Write-Host "  [$($result.topic)] $($result.title)" -ForegroundColor White
                Write-Host "    路径: $($result.path)" -ForegroundColor Gray
                if ($result.summary) {
                    Write-Host "    摘要: $($result.summary.Substring(0, [Math]::Min(80, $result.summary.Length)))..." -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
}
