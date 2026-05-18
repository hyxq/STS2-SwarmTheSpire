<#
.SYNOPSIS
    使用 ILSpy 反编译 STS2 游戏 DLL（跨平台）。

.DESCRIPTION
    将 sts2.dll 反编译为 C# 源码，输出到缓存目录。
    ilspycmd 是基于 .NET 的跨平台工具，支持 Windows、macOS 和 Linux。

.PARAMETER DllPath
    sts2.dll 的完整路径

.PARAMETER OutputDir
    反编译输出目录，默认为脚本所在目录的上级目录下的 cache/decompiled/sts2

.PARAMETER Force
    强制重新反编译，即使输出目录已存在

.EXAMPLE
    # Windows
    pwsh -File decompile-sts2.ps1 -DllPath "D:/Steam/steamapps/common/Slay the Spire 2/data_sts2_windows_x86_64/sts2.dll"

    # macOS
    pwsh -File decompile-sts2.ps1 -DllPath "$HOME/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/data_sts2_macos_x86_64/sts2.dylib"

    # Linux
    pwsh -File decompile-sts2.ps1 -DllPath "$HOME/.steam/steam/steamapps/common/Slay the Spire 2/data_sts2_linux_x86_64/libsts2.so"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$DllPath,
    [string]$OutputDir,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# 验证 DLL 路径
if (-not (Test-Path $DllPath)) {
    Write-Error "[ERROR] DLL 文件不存在: $DllPath"
    exit 1
}

# 默认输出目录
if (-not $OutputDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $OutputDir = Join-Path (Split-Path -Parent $scriptDir) "cache" "decompiled" "sts2"
}

# 显示平台信息
$platform = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "macOS" } else { "Linux" }
Write-Host "[INFO] 平台: $platform" -ForegroundColor Gray

# 检查是否已存在
if ((Test-Path $OutputDir) -and -not $Force) {
    $files = Get-ChildItem -Path $OutputDir -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
        Write-Host "[INFO] 反编译输出已存在 ($($files.Count) 个文件)，使用 -Force 强制重新反编译" -ForegroundColor Green
        Write-Host "[INFO] 输出目录: $OutputDir" -ForegroundColor Green
        return
    }
}

# 检查 ilspycmd 是否可用
$ilspyCmd = Get-Command ilspycmd -ErrorAction SilentlyContinue
if (-not $ilspyCmd) {
    Write-Host "[WARN] ilspycmd 未安装" -ForegroundColor Yellow

    # 检查是否可以安装
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        Write-Host "[INFO] 正在安装 ilspycmd..." -ForegroundColor Cyan
        dotnet tool install -g ilspycmd
        if ($LASTEXITCODE -ne 0) {
            Write-Error "[ERROR] 安装 ilspycmd 失败，请手动安装: dotnet tool install -g ilspycmd"
            exit 1
        }

        # 刷新 PATH（跨平台）
        if ($IsWindows) {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
        } else {
            # macOS/Linux: 添加 ~/.dotnet/tools 到 PATH
            $dotnetToolsPath = Join-Path $env:HOME ".dotnet" "tools"
            if (Test-Path $dotnetToolsPath) {
                $env:PATH = "$dotnetToolsPath`:$env:PATH"
            }
        }

        $ilspyCmd = Get-Command ilspycmd -ErrorAction SilentlyContinue
        if (-not $ilspyCmd) {
            Write-Error "[ERROR] 安装后仍无法找到 ilspycmd，请重启终端或运行: source ~/.bashrc"
            exit 1
        }
    } else {
        Write-Error "[ERROR] dotnet 未安装，无法自动安装 ilspycmd"
        Write-Host "请先安装 .NET SDK: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
        exit 1
    }
}

# 确保输出目录存在
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 执行反编译
Write-Host "[INFO] 开始反编译 STS2..." -ForegroundColor Cyan
Write-Host "[INFO] DLL: $DllPath" -ForegroundColor Gray
Write-Host "[INFO] 输出: $OutputDir" -ForegroundColor Gray

$startTime = Get-Date

# ilspycmd -p -o <output> <dll>
ilspycmd -p -o $OutputDir $DllPath

if ($LASTEXITCODE -eq 0) {
    $elapsed = (Get-Date) - $startTime
    $fileCount = (Get-ChildItem -Path $OutputDir -Filter "*.cs" -Recurse).Count
    Write-Host "[INFO] 反编译完成！" -ForegroundColor Green
    Write-Host "[INFO] 文件数: $fileCount" -ForegroundColor Green
    Write-Host "[INFO] 耗时: $([math]::Round($elapsed.TotalSeconds, 1)) 秒" -ForegroundColor Green
} else {
    Write-Error "[ERROR] 反编译失败"
    exit 1
}
