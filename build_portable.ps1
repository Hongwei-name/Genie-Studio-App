# ============================================================
# 创建便携版 ZIP 包
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   创建便携版 ZIP 包" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 检查构建目录
$releaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    Write-Host "❌ 错误: 未找到构建目录，请先运行 build_installer.bat" -ForegroundColor Red
    exit 1
}

# 创建输出目录
$outputDir = "dist"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# 生成版本号
$version = Get-Date -Format "yyyyMMdd_HHmmss"
$zipName = "genie_review_assistant_portable_$version.zip"
$zipPath = Join-Path $outputDir $zipName

Write-Host "📦 正在打包..." -ForegroundColor Yellow

# 创建 ZIP 文件
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -Force

if (Test-Path $zipPath) {
    $fileSize = (Get-Item $zipPath).Length / 1MB
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "✅ 便携版打包成功！" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 文件位置:" -ForegroundColor Cyan
    Write-Host "   $zipPath" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 文件大小: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 使用说明:" -ForegroundColor Cyan
    Write-Host "   1. 解压 ZIP 文件到任意位置" -ForegroundColor White
    Write-Host "   2. 双击 genie_review_assistant.exe 运行" -ForegroundColor White
    Write-Host "   3. 无需安装，直接使用" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ 打包失败" -ForegroundColor Red
    exit 1
}
