# 🎉 智元标注审核助手 - 安装程序制作快速指南

## 📁 文件位置

所有安装程序相关文件都在 `installer/` 目录中：

```
installer/
├── installer.iss           # Inno Setup 脚本（核心文件）
├── build_setup.bat         # 一键构建安装程序
├── build_installer.bat     # 构建 Flutter 应用
├── build_installer.ps1     # PowerShell 构建脚本
├── build_portable.ps1      # 便携版打包脚本
├── check_inno.ps1          # 检查 Inno Setup 工具
├── assets/                 # 安装程序资源（图片等）
├── INSTALLER_README.md     # 详细说明文档
├── PACKAGING.md            # 打包选项说明
└── QUICK_START.md          # 本文件
```

---

## 🚀 快速开始（3 步完成）

### 第1步：安装 Inno Setup 6

**下载地址：** https://jrsoftware.org/isinfo.php

安装时确保勾选 **"ChineseSimplified"** 语言包

---

### 第2步：构建 Flutter 应用

打开 PowerShell，运行：

```powershell
cd D:\project\Genie-Studio-App
flutter clean
flutter pub get
flutter build windows --release
```

---

### 第3步：生成安装程序

**方法A：一键生成（推荐）**

```powershell
cd D:\project\Genie-Studio-App
.\installer\build_setup.bat
```

**方法B：使用 PowerShell**

```powershell
cd D:\project\Genie-Studio-App
.\installer\build_installer.ps1
```

**方法C：手动生成**

1. 用 Inno Setup 编辑器打开 `installer\installer.iss`
2. 按 F9 或点击 "构建" → "编译"
3. 等待编译完成

---

## 📦 输出文件

生成的安装程序位置：

```
D:\project\Genie-Studio-App\installer_output\genie_review_assistant_setup_1.0.0.exe
```

**文件大小：** 约 20-30 MB

---

## 🎯 安装程序功能

用户双击运行后会看到：

```
┌─────────────────────────────────────┐
│    智元标注审核助手 安装向导         │
├─────────────────────────────────────┤
│                                     │
│  欢迎使用 智元标注审核助手           │
│                                     │
│  本向导将引导您完成安装。           │
│                                     │
│  点击 "下一步" 继续...              │
│                                     │
│         [下一步]    [取消]           │
└─────────────────────────────────────┘
```

**用户可以选择：**
- ✅ 安装路径（默认：C:\Program Files\智元标注审核助手）
- ✅ 创建桌面快捷方式
- ✅ 查看许可证协议
- ✅ 安装完成后启动应用

---

## 📤 分发给用户

**发送文件：**
```
genie_review_assistant_setup_1.0.0.exe
```

**用户操作：**
1. 双击运行安装程序
2. 按照向导提示操作
3. 安装完成！
4. 从桌面或开始菜单启动应用

---

## ⚠️ 重要提示

1. **需要先安装 Inno Setup 6** 才能生成安装程序
2. 用户需要安装 **WebView2 Runtime** 才能运行应用（安装程序会自动提示）
3. 首次运行可能有 Windows 安全警告（点击"更多信息" → "仍要运行"）

---

## 🔧 自定义配置

### 修改应用信息

编辑 `installer\installer.iss` 文件：

```ini
[Setup]
AppName=智元标注审核助手          ; 应用名称
AppVersion=1.0.0                   ; 版本号
AppPublisher=GenieStudio           ; 发布者
DefaultDirName={autopf}\智元标注审核助手  ; 默认安装路径
OutputBaseFilename=genie_review_assistant_setup_1.0.0  ; 输出文件名
```

### 修改图标

替换 `windows\runner\resources\app_icon.ico` 文件

### 添加自定义图片

在 `installer\assets\` 目录添加：
- `wizard_image.bmp` - 安装向导左侧图片（164x314 像素）
- `wizard_small.bmp` - 安装向导右上角图片（55x55 像素）

---

## 📚 更多信息

- **详细文档：** 查看 `INSTALLER_README.md`
- **打包选项：** 查看 `PACKAGING.md`

---

## 🐛 常见问题

### Q: 提示找不到 Inno Setup
**A:** 需要先安装 Inno Setup 6：https://jrsoftware.org/isinfo.php

### Q: 编译时提示找不到文件
**A:** 确保已运行 `flutter build windows --release`

### Q: 安装后无法运行
**A:** 安装 WebView2 Runtime

### Q: 如何修改版本号？
**A:** 修改 `installer.iss` 中的 `AppVersion`

### Q: 如何修改应用名称？
**A:** 修改 `installer.iss` 中的 `AppName`

---

## ✅ 完成！

按照上述步骤操作后，你将拥有一个专业的 Windows 安装程序，用户可以：
- 双击运行安装向导
- 选择安装路径
- 创建桌面快捷方式
- 完整卸载应用

**开始制作：** 双击 `installer\build_setup.bat` 或查看详细文档
