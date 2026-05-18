<#
.SYNOPSIS
    使用 RitsuLib Mod Template 创建新的 Mod 项目。

.DESCRIPTION
    从 NuGet 包 STS2.RitsuLib.ModTemplate 创建 Mod 项目模板。
    自动安装模板（如需要）并生成项目结构。

.PARAMETER Name
    Mod 项目名称

.PARAMETER OutputDir
    输出目录，默认为当前目录

.PARAMETER Force
    强制重新安装模板

.EXAMPLE
    pwsh -File create-mod.ps1 -Name "MyAwesomeMod"
    pwsh -File create-mod.ps1 -Name "MyMod" -OutputDir "D:/Projects"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$OutputDir = ".",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  创建 RitsuLib Mod 项目" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 显示平台信息
$platform = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }
Write-Host "平台: $platform" -ForegroundColor Gray

# 检查 dotnet 是否可用
$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnetCmd) {
    Write-Error "[ERROR] dotnet 未安装。请先安装 .NET SDK：https://dotnet.microsoft.com/download"
    exit 1
}

# 检查模板是否已安装
Write-Host "[1/3] 检查模板..." -ForegroundColor Yellow
$templateList = dotnet new list ritsulibmod 2>&1
$templateInstalled = $templateList -match "ritsulibmod"

if (-not $templateInstalled -or $Force) {
    Write-Host "  安装 STS2.RitsuLib.ModTemplate..." -ForegroundColor Cyan
    dotnet new install STS2.RitsuLib.ModTemplate::1.0.3

    if ($LASTEXITCODE -ne 0) {
        Write-Error "[ERROR] 安装模板失败"
        exit 1
    }
    Write-Host "  模板安装成功" -ForegroundColor Green
} else {
    Write-Host "  模板已安装" -ForegroundColor Green
}

# 创建输出目录
$outputPath = Join-Path $OutputDir $Name
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 创建项目
Write-Host "`n[2/3] 创建项目..." -ForegroundColor Yellow
Push-Location $OutputDir
try {
    dotnet new ritsulibmod -n $Name

    if ($LASTEXITCODE -ne 0) {
        Write-Error "[ERROR] 创建项目失败"
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host "  项目创建成功: $outputPath" -ForegroundColor Green

# 配置说明
Write-Host "`n[3/3] 后续步骤..." -ForegroundColor Yellow

Write-Host "`n项目已创建！请按以下步骤配置：" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 进入项目目录：" -ForegroundColor White
Write-Host "   cd $outputPath" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 复制并编辑本地配置文件：" -ForegroundColor White
Write-Host "   cp local.props.template local.props" -ForegroundColor Gray
Write-Host "   # 编辑 local.props 设置游戏安装目录等路径" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 构建项目：" -ForegroundColor White
Write-Host "   dotnet build" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 快速构建（跳过资源复制）：" -ForegroundColor White
Write-Host "   dotnet build /p:RunPckExport=false /p:CopyModOnBuild=false" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  项目创建完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
