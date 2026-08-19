# ============================================================
# zero_K-Genie - 一键生成安装程序
# ============================================================
# 使用方法:
#   1. 右键点击此文件
#   2. 选择 "使用 PowerShell 运行"
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   zero_K-Genie - 安装程序生成工具" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 切换到项目根目录
$projectRoot = "D:\project\Genie-Studio-App"
Set-Location $projectRoot
Write-Host "📁 项目目录: $projectRoot" -ForegroundColor White
Write-Host ""

# 从 pubspec.yaml 自动递增补丁版本，并同步所有 Windows/安装程序版本信息。
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$pubspec = [System.IO.File]::ReadAllText($pubspecPath)
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$')
if (-not $versionMatch.Success) {
    Write-Host "❌ 无法从 pubspec.yaml 读取版本号" -ForegroundColor Red
    exit 1
}

$major = [int]$versionMatch.Groups[1].Value
$minor = [int]$versionMatch.Groups[2].Value
$patch = [int]$versionMatch.Groups[3].Value + 1
$version = "$major.$minor.$patch"
$buildVersion = "$version+1"
$msixVersion = "$version.0"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$pubspec = [regex]::Replace($pubspec, '(?m)^version:\s*.*$', "version: $buildVersion")
$pubspec = [regex]::Replace($pubspec, '(?m)^\s*msix_version:\s*.*$', "  msix_version: $msixVersion")
[System.IO.File]::WriteAllText($pubspecPath, $pubspec, $utf8NoBom)

$installerPath = Join-Path $projectRoot "installer\installer.iss"
$installer = [System.IO.File]::ReadAllText($installerPath)
$installer = [regex]::Replace($installer, '(?m)^#define MyAppVersion "[^"]+"', ('#define MyAppVersion "' + $version + '"'))
[System.IO.File]::WriteAllText($installerPath, $installer, $utf8NoBom)

$setupPath = Join-Path $projectRoot "installer\setup.iss"
$setup = [System.IO.File]::ReadAllText($setupPath)
$setup = [regex]::Replace($setup, '(?m)^AppVersion=.*$', "AppVersion=$version")
$setup = [regex]::Replace($setup, '(?m)^OutputBaseFilename=.*$', "OutputBaseFilename=GenieStudio_Setup_v$version")
[System.IO.File]::WriteAllText($setupPath, $setup, $utf8NoBom)

$runnerRcPath = Join-Path $projectRoot "windows\runner\Runner.rc"
$runnerRc = [System.IO.File]::ReadAllText($runnerRcPath)
$runnerRc = [regex]::Replace($runnerRc, '(?m)^#define VERSION_AS_STRING "[^"]+"', ('#define VERSION_AS_STRING "' + $version + '"'))
[System.IO.File]::WriteAllText($runnerRcPath, $runnerRc, $utf8NoBom)

Write-Host "✅ 版本已自动递增到 $version" -ForegroundColor Green
Write-Host ""

# 步骤 1: 构建 Flutter Release
Write-Host "[1/3] 构建 Flutter Release 版本..." -ForegroundColor Yellow
Write-Host "这可能需要几分钟时间，请耐心等待..." -ForegroundColor Gray
Write-Host ""

# 清理
Write-Host "  清理旧构建..." -ForegroundColor Gray
flutter clean 2>&1 | Out-Null

# 获取依赖
Write-Host "  获取依赖..." -ForegroundColor Gray
flutter pub get 2>&1 | Out-Null

# 构建
Write-Host "  构建 Windows 版本..." -ForegroundColor Gray
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Flutter 构建失败" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

Write-Host ""
Write-Host "✅ Flutter 构建完成" -ForegroundColor Green
Write-Host ""

# 步骤 2: 生成安装程序
Write-Host "[2/3] 生成安装程序..." -ForegroundColor Yellow

# 检查 Inno Setup
$isccPath = "D:\software\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    Write-Host "❌ 错误: 找不到 Inno Setup" -ForegroundColor Red
    Write-Host "   路径: $isccPath" -ForegroundColor Gray
    exit 1
}

Write-Host "  找到 Inno Setup: $isccPath" -ForegroundColor Gray
Write-Host ""

# 创建输出目录
$outputDir = "$projectRoot\installer_output"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# 编译安装程序
Write-Host "  正在编译安装程序..." -ForegroundColor Gray
$issFile = "$projectRoot\installer\installer.iss"

& $isccPath $issFile

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ 安装程序生成失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[3/3] 完成!" -ForegroundColor Green
Write-Host ""

# 检查输出文件
$setupFile = "$outputDir\zero_K-Genie_Setup_$version.exe"
if (Test-Path $setupFile) {
    $fileSize = [math]::Round((Get-Item $setupFile).Length / 1MB, 2)
    
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "✅ 安装程序生成成功！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 安装程序位置:" -ForegroundColor Cyan
    Write-Host "   $setupFile" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 文件大小: $fileSize MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 下一步:" -ForegroundColor Cyan
    Write-Host "   1. 将安装程序发给用户" -ForegroundColor White
    Write-Host "   2. 用户双击运行即可安装" -ForegroundColor White
    Write-Host ""
    
} else {
    Write-Host "❌ 未找到生成的安装程序" -ForegroundColor Red
    exit 1
}

Write-Host ""
