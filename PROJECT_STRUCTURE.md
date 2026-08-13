# 智元标注审核助手 - 标准项目结构

## 📁 推荐的项目结构

```
Genie-Studio-App/
├── 📄 README.md                    # 项目说明文档
├── 📄 LICENSE.txt                  # 许可证
├── 📄 pubspec.yaml                 # Dart 依赖配置
├── 📄 pubspec.lock                 # 依赖锁定文件
├── 📄 analysis_options.yaml        # 代码分析配置
├── 📄 .gitignore                   # Git 忽略规则
├── 📄 .metadata                    # Flutter 元数据
│
├── 📁 lib/                         # 源代码目录
│   ├── 📄 app.dart                 # 应用入口 Widget
│   ├── 📄 main.dart                # 主函数
│   ├── 📁 core/                    # 核心功能
│   │   ├── 📁 config/              # 配置
│   │   ├── 📁 network/             # 网络请求
│   │   ├── 📁 theme/               # 主题样式
│   │   └── 📁 utils/               # 工具类
│   ├── 📁 data/                    # 数据层
│   │   ├── 📁 models/              # 数据模型
│   │   ├── 📁 repositories/        # 仓库层
│   │   └── 📁 storage/             # 本地存储
│   ├── 📁 features/                # 功能模块
│   │   ├── 📁 config/              # 配置页面
│   │   ├── 📁 fail_eps/            # 失败 EP 页面
│   │   ├── 📁 logs/                # 日志页面
│   │   ├── 📁 shell/               # 主框架
│   │   ├── 📁 stats/               # 统计页面
│   │   ├── 📁 tasks/               # 任务页面
│   │   └── 📁 webview/             # WebView 页面
│   └── 📁 providers/               # 状态管理
│
├── 📁 test/                        # 测试目录
│   ├── 📄 episode_test.dart
│   └── 📄 widget_test.dart
│
├── 📁 windows/                     # Windows 平台文件
│   ├── 📁 flutter/                 # Flutter 平台配置
│   └── 📁 runner/                  # Windows 运行器
│
├── 📁 tools/                       # 工具脚本
│   └── 📄 sign-windows-release.ps1
│
└── 📁 installer/                   # 安装程序（可选）
    ├── 📄 installer.iss            # Inno Setup 脚本
    ├── 📄 build_setup.bat          # 一键构建
    ├── 📄 check_inno.ps1           # 检查工具
    └── 📁 assets/                  # 安装程序资源
```

---

## 🗑️ 需要删除的文件

### 临时文件（已自动忽略）
- `flutter-run.stderr.log`
- `flutter-run.stdout.log`
- `*.log`

### IDE 配置文件（已自动忽略）
- `.idea/` 目录
- `*.iml` 文件

### 需要手动整理
- `开发文档.md` → 移到 `docs/` 目录或删除
- `智元标注审核助手.txt` → 移到 `docs/` 目录或删除

---

## 📦 安装程序文件整理

将安装程序相关文件移到 `installer/` 目录：

```powershell
# 创建 installer 目录
mkdir installer

# 移动文件
Move-Item installer.iss installer/
Move-Item build_setup.bat installer/
Move-Item build_installer.bat installer/
Move-Item build_installer.ps1 installer/
Move-Item build_portable.ps1 installer/
Move-Item check_inno.ps1 installer/
Move-Item installer_assets installer/assets
Move-Item INSTALLER_README.md installer/
Move-Item PACKAGING.md installer/
Move-Item QUICK_START.md installer/
```

---

## 📚 文档整理

创建 `docs/` 目录存放文档：

```powershell
mkdir docs
Move-Item 开发文档.md docs/
Move-Item 智元标注审核助手.txt docs/
```

---

## ✅ 标准化后的优势

1. **清晰的目录结构** - 一目了然
2. **符合 Flutter 规范** - 标准的 Flutter 项目结构
3. **便于维护** - 相关文件归类存放
4. **Git 友好** - 正确配置忽略规则
5. **易于协作** - 团队成员快速理解项目

---

## 🔧 自动整理脚本

运行以下 PowerShell 脚本自动整理：

```powershell
# 整理项目结构脚本
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   整理项目结构" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

cd D:\project\Genie-Studio-App

# 创建目录
Write-Host "📁 创建目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "installer" -Force | Out-Null
New-Item -ItemType Directory -Path "docs" -Force | Out-Null

# 移动安装程序文件
Write-Host "📦 移动安装程序文件..." -ForegroundColor Yellow
$installerFiles = @(
    "installer.iss",
    "build_setup.bat",
    "build_installer.bat",
    "build_installer.ps1",
    "build_portable.ps1",
    "check_inno.ps1",
    "INSTALLER_README.md",
    "PACKAGING.md",
    "QUICK_START.md"
)

foreach ($file in $installerFiles) {
    if (Test-Path $file) {
        Move-Item $file "installer/" -Force
        Write-Host "   ✅ $file" -ForegroundColor Green
    }
}

# 移动资源目录
if (Test-Path "installer_assets") {
    Move-Item "installer_assets" "installer/assets" -Force
    Write-Host "   ✅ installer_assets" -ForegroundColor Green
}

# 移动文档文件
Write-Host "📚 移动文档文件..." -ForegroundColor Yellow
$docFiles = @(
    "开发文档.md",
    "智元标注审核助手.txt"
)

foreach ($file in $docFiles) {
    if (Test-Path $file) {
        Move-Item $file "docs/" -Force
        Write-Host "   ✅ $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "✅ 整理完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📁 新的目录结构:" -ForegroundColor Cyan
Get-ChildItem -Depth 1 | Select-Object Name, @{N='Type';E={if($_.PSIsContainer){'📁'}else{'📄'}}} | Format-Table -AutoSize
```

---

## 📝 下一步

1. 运行上述整理脚本
2. 更新 `.gitignore`（如果需要）
3. 提交更改：
   ```powershell
   git add .
   git commit -m "refactor: 整理项目结构，移动安装程序和文档到专用目录"
   git push origin main
   ```
