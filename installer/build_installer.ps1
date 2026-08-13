# ============================================================
# zero_K-Genie - 一键打包脚本
# ============================================================
# 使用方法:
#   1. 打开 PowerShell
#   2. 切换到项目目录: cd D:\project\Genie-Studio-App
#   3. 运行脚本: .\installer\build_installer.ps1
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   zero_K-Genie - 打包工具" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 切换到项目根目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# 检查 Flutter 是否安装
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "❌ 错误: 未找到 Flutter，请先安装 Flutter SDK" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter 已安装: $($flutterPath.Source)" -ForegroundColor Green
Write-Host ""

# 清理旧的构建
Write-Host "📦 步骤 1/3: 清理旧的构建文件..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 清理失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 清理完成" -ForegroundColor Green

# 获取依赖
Write-Host ""
Write-Host "📦 步骤 2/3: 获取依赖..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 获取依赖失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 依赖获取完成" -ForegroundColor Green

# 构建 Release 版本
Write-Host ""
Write-Host "📦 步骤 3/3: 构建 Windows Release 版本..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 构建失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 构建完成" -ForegroundColor Green

# 检查输出文件
$releaseDir = "build\windows\x64\runner\Release"
if (Test-Path $releaseDir) {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "✅ 打包成功！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 输出目录:" -ForegroundColor Cyan
    Write-Host "   $releaseDir" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 包含文件:" -ForegroundColor Cyan
    Get-ChildItem -Path $releaseDir -File | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "   - $($_.Name) ($size MB)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "📝 下一步:" -ForegroundColor Cyan
    Write-Host "   1. 运行 installer\Generate-Setup.ps1 生成安装程序" -ForegroundColor White
    Write-Host "   2. 或者将 Release 文件夹打包发给用户" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ 打包失败，未找到输出目录" -ForegroundColor Red
    exit 1
}
