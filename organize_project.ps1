# ============================================================
# 智元标注审核助手 - 项目结构整理脚本
# ============================================================
# 运行方法: .\organize_project.ps1
# ============================================================

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   智元标注审核助手 - 项目结构整理" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 切换到项目目录
$projectRoot = "D:\project\Genie-Studio-App"
if (-not (Test-Path $projectRoot)) {
    Write-Host "❌ 错误: 找不到项目目录 $projectRoot" -ForegroundColor Red
    exit 1
}

Set-Location $projectRoot
Write-Host "📁 当前目录: $projectRoot" -ForegroundColor White
Write-Host ""

# 步骤 1: 创建目录结构
Write-Host "[1/4] 创建目录结构..." -ForegroundColor Yellow
$directories = @(
    "installer",
    "installer\assets",
    "docs"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "   ✅ 创建: $dir" -ForegroundColor Green
    } else {
        Write-Host "   ✓ 已存在: $dir" -ForegroundColor Gray
    }
}
Write-Host ""

# 步骤 2: 移动安装程序文件
Write-Host "[2/4] 整理安装程序文件..." -ForegroundColor Yellow
$installerFiles = @(
    @{Source="installer.iss"; Dest="installer\"},
    @{Source="build_setup.bat"; Dest="installer\"},
    @{Source="build_installer.bat"; Dest="installer\"},
    @{Source="build_installer.ps1"; Dest="installer\"},
    @{Source="build_portable.ps1"; Dest="installer\"},
    @{Source="check_inno.ps1"; Dest="installer\"},
    @{Source="INSTALLER_README.md"; Dest="installer\"},
    @{Source="PACKAGING.md"; Dest="installer\"},
    @{Source="QUICK_START.md"; Dest="installer\"}
)

$movedCount = 0
foreach ($item in $installerFiles) {
    if (Test-Path $item.Source) {
        Move-Item -Path $item.Source -Destination $item.Dest -Force
        Write-Host "   ✅ $($item.Source)" -ForegroundColor Green
        $movedCount++
    }
}

# 移动资源目录
if (Test-Path "installer_assets") {
    # 如果目标已存在，先删除
    if (Test-Path "installer\assets") {
        Remove-Item -Path "installer\assets" -Recurse -Force
    }
    Move-Item -Path "installer_assets" -Destination "installer\assets" -Force
    Write-Host "   ✅ installer_assets\" -ForegroundColor Green
    $movedCount++
}

Write-Host "   📊 移动了 $movedCount 个文件/目录" -ForegroundColor Cyan
Write-Host ""

# 步骤 3: 移动文档文件
Write-Host "[3/4] 整理文档文件..." -ForegroundColor Yellow
$docFiles = @(
    @{Source="开发文档.md"; Dest="docs\"},
    @{Source="智元标注审核助手.txt"; Dest="docs\"}
)

$movedDocCount = 0
foreach ($item in $docFiles) {
    if (Test-Path $item.Source) {
        Move-Item -Path $item.Source -Destination $item.Dest -Force
        Write-Host "   ✅ $($item.Source)" -ForegroundColor Green
        $movedDocCount++
    }
}

Write-Host "   📊 移动了 $movedDocCount 个文档" -ForegroundColor Cyan
Write-Host ""

# 步骤 4: 清理临时文件
Write-Host "[4/4] 清理临时文件..." -ForegroundColor Yellow
$tempFiles = @(
    "flutter-run.stderr.log",
    "flutter-run.stdout.log",
    "genie_review_assistant.iml"
)

$cleanedCount = 0
foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force
        Write-Host "   🗑️ 删除: $file" -ForegroundColor Yellow
        $cleanedCount++
    }
}

# 删除 .idea 目录
if (Test-Path ".idea") {
    Remove-Item -Path ".idea" -Recurse -Force
    Write-Host "   🗑️ 删除: .idea\" -ForegroundColor Yellow
    $cleanedCount++
}

Write-Host "   📊 清理了 $cleanedCount 个文件" -ForegroundColor Cyan
Write-Host ""

# 显示最终结构
Write-Host "=====================================" -ForegroundColor Green
Write-Host "✅ 整理完成！" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "📁 项目结构:" -ForegroundColor Cyan
Write-Host ""

# 显示顶层结构
Get-ChildItem -Depth 0 | ForEach-Object {
    $icon = if ($_.PSIsContainer) { "📁" } else { "📄" }
    $color = if ($_.PSIsContainer) { "Yellow" } else { "White" }
    Write-Host "   $icon $($_.Name)" -ForegroundColor $color
}

Write-Host ""
Write-Host "📂 主要目录内容:" -ForegroundColor Cyan
Write-Host ""

# 显示子目录
$mainDirs = @("lib", "installer", "docs", "windows", "test", "tools")
foreach ($dir in $mainDirs) {
    if (Test-Path $dir) {
        Write-Host "   📁 $dir/" -ForegroundColor Yellow
        Get-ChildItem -Path $dir -Depth 0 | Select-Object -First 5 | ForEach-Object {
            $icon = if ($_.PSIsContainer) { "📁" } else { "📄" }
            Write-Host "      $icon $($_.Name)" -ForegroundColor Gray
        }
        $itemCount = (Get-ChildItem -Path $dir -Recurse -File).Count
        Write-Host "      ... 共 $itemCount 个文件" -ForegroundColor DarkGray
        Write-Host ""
    }
}

Write-Host "📝 下一步操作:" -ForegroundColor Cyan
Write-Host "   1. 检查文件是否正确移动" -ForegroundColor White
Write-Host "   2. 更新 installer.iss 中的路径（如果需要）" -ForegroundColor White
Write-Host "   3. 提交更改: git add . && git commit -m 'refactor: 整理项目结构'" -ForegroundColor White
Write-Host ""
