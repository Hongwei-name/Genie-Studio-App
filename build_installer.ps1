# ============================================================
# 智元标注审核助手 - 一键打包脚本
# ============================================================
# 使用方法:
#   1. 打开 PowerShell
#   2. 切换到项目目录: cd D:\project\Genie-Studio-App
#   3. 运行脚本: .\build_installer.ps1
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   智元标注审核助手 - 打包工具" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

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

# 生成 MSIX 安装包
Write-Host ""
Write-Host "📦 正在生成 MSIX 安装包..." -ForegroundColor Yellow
dart run msix:create
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ MSIX 生成失败" -ForegroundColor Red
    exit 1
}

# 检查输出文件
$msixPath = "build\windows\x64\runner\Release\genie_review_assistant.msix"
if (Test-Path $msixPath) {
    $fileSize = (Get-Item $msixPath).Length / 1MB
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "✅ 打包成功！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 MSIX 安装包位置:" -ForegroundColor Cyan
    Write-Host "   $msixPath" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 文件大小: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 安装说明:" -ForegroundColor Cyan
    Write-Host "   1. 双击 msix 文件即可安装" -ForegroundColor White
    Write-Host "   2. 支持 Windows 10 1809 及以上版本" -ForegroundColor White
    Write-Host "   3. 安装后可在开始菜单找到应用" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ 打包失败，未找到 MSIX 文件" -ForegroundColor Red
    exit 1
}
