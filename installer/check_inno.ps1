# ============================================================
# 检查 Inno Setup 安装状态
# ============================================================
# 使用方法:
#   1. 打开 PowerShell
#   2. 运行脚本: .\installer\check_inno.ps1
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   检查 Inno Setup 安装状态" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 检查注册表中的 Inno Setup
$isInstalled = $false
$installPath = ""

# 检查 64 位注册表
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
if (Test-Path $regPath) {
    $installPath = (Get-ItemProperty -Path $regPath -Name "InstallLocation").InstallLocation
    $isInstalled = $true
}

# 检查 32 位注册表
if (-not $isInstalled) {
    $regPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    if (Test-Path $regPath) {
        $installPath = (Get-ItemProperty -Path $regPath -Name "InstallLocation").InstallLocation
        $isInstalled = $true
    }
}

# 检查用户注册表
if (-not $isInstalled) {
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    if (Test-Path $regPath) {
        $installPath = (Get-ItemProperty -Path $regPath -Name "InstallLocation").InstallLocation
        $isInstalled = $true
    }
}

if ($isInstalled) {
    Write-Host "✅ Inno Setup 6 已安装" -ForegroundColor Green
    Write-Host "   安装路径: $installPath" -ForegroundColor White
    Write-Host ""
    Write-Host "📁 ISCC.exe 位置: $installPath\ISCC.exe" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📝 下一步:" -ForegroundColor Yellow
    Write-Host "   双击运行 installer\build_setup.bat 生成安装程序" -ForegroundColor White
} else {
    Write-Host "❌ 未找到 Inno Setup 6" -ForegroundColor Red
    Write-Host ""
    Write-Host "📥 请先安装 Inno Setup 6:" -ForegroundColor Yellow
    Write-Host "   https://jrsoftware.org/isinfo.php" -ForegroundColor White
    Write-Host ""
    Write-Host "安装时请确保勾选 'ChineseSimplified' 语言包" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "安装完成后重新运行此脚本" -ForegroundColor Cyan
}

Write-Host ""
