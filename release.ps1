# ============================================================
# GitHub Release 发布脚本
# ============================================================
# 使用方法:
#   1. 确保已安装 GitHub CLI (gh)
#   2. 运行脚本: .\release.ps1
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   zero_K-Genie - GitHub Release 发布" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 切换到项目根目录
$projectRoot = "D:\project\Genie-Studio-App"
Set-Location $projectRoot

# 检查是否已构建
$setupFile = "installer_output\zero_K-Genie_Setup_1.0.0.exe"
if (-not (Test-Path $setupFile)) {
    Write-Host "❌ 错误: 未找到安装程序" -ForegroundColor Red
    Write-Host "请先运行: .\installer\Generate-Setup.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 找到安装程序: $setupFile" -ForegroundColor Green
Write-Host ""

# 检查 GitHub CLI
$ghPath = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghPath) {
    Write-Host "❌ 错误: 未找到 GitHub CLI" -ForegroundColor Red
    Write-Host "请先安装: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI 已安装" -ForegroundColor Green
Write-Host ""

# 检查是否已登录
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 错误: 未登录 GitHub" -ForegroundColor Red
    Write-Host "请先运行: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 已登录 GitHub" -ForegroundColor Green
Write-Host ""

# 读取 Release 文档
$releaseNotes = Get-Content -Path "RELEASE_NOTES.md" -Raw

Write-Host "📝 Release 文档已加载" -ForegroundColor Yellow
Write-Host ""

# 创建 Release
Write-Host "🚀 正在创建 Release..." -ForegroundColor Yellow
Write-Host ""

try {
    # 创建 Tag
    Write-Host "  创建 Tag: v1.0.0" -ForegroundColor Gray
    git tag -a v1.0.0 -m "Release v1.0.0"
    git push origin v1.0.0

    # 创建 Release
    Write-Host "  创建 Release..." -ForegroundColor Gray
    gh release create v1.0.0 `
        --title "v1.0.0" `
        --notes $releaseNotes `
        --latest `
        $setupFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host "✅ Release 发布成功！" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔗 Release 链接:" -ForegroundColor Cyan
        Write-Host "   https://github.com/Hongwei-name/Genie-Studio-App/releases/tag/v1.0.0" -ForegroundColor White
        Write-Host ""
        Write-Host "📦 已上传附件:" -ForegroundColor Cyan
        Write-Host "   - zero_K-Genie_Setup_1.0.0.exe" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ Release 创建失败" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ 发生错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📝 下一步:" -ForegroundColor Cyan
Write-Host "   1. 访问 Release 页面查看" -ForegroundColor White
Write-Host "   2. 分享链接给用户" -ForegroundColor White
Write-Host "   3. 收集用户反馈" -ForegroundColor White
Write-Host ""
