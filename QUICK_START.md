# 🎉 智元标注审核助手 - 安装程序制作完整指南

## 📋 当前状态

✅ 已创建：
- Inno Setup 脚本文件 (installer.iss)
- 一键构建脚本 (build_setup.bat)
- 检查工具 (check_inno.ps1)
- 许可证文件 (LICENSE.txt)
- 安装程序资源目录 (installer_assets/)

❌ 需要安装：
- Inno Setup 6

---

## 🚀 快速开始（3 步完成）

### 第1步：下载并安装 Inno Setup 6

**下载地址：**
https://jrsoftware.org/isinfo.php

**安装步骤：**
1. 下载 Inno Setup 6 安装程序
2. 运行安装程序
3. 在 "选择语言" 界面，勾选 "ChineseSimplified"
4. 完成安装

---

### 第2步：构建 Flutter Release 版本

打开 PowerShell，运行：

```powershell
cd D:\project\Genie-Studio-App
flutter clean
flutter pub get
flutter build windows --release
```

等待构建完成（可能需要几分钟）

---

### 第3步：生成安装程序

**方法A：一键生成（推荐）**

双击运行：
```
D:\project\Genie-Studio-App\build_setup.bat
```

**方法B：手动生成**

1. 用 Inno Setup 编辑器打开 `installer.iss`
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

### 安装向导界面
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

### 安装选项
- ✅ 选择安装路径（默认：C:\Program Files\智元标注审核助手）
- ✅ 创建桌面快捷方式
- ☐ 创建快速启动栏图标
- ✅ 查看许可证协议

### 安装完成后
- 自动创建开始菜单
- 可选立即运行应用
- 支持完整卸载

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

### 用户需要安装 WebView2 Runtime

如果用户首次运行时提示缺少 WebView2，可以：

**方法1：安装程序自动提示**
- 安装程序会检测并提示下载

**方法2：用户自行安装**
- 下载地址：https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- 选择 "Evergreen Bootstrapper" 版本

### Windows 安全警告

首次运行安装程序时，可能会显示：
- "Windows 已保护你的电脑"
- 点击 "更多信息" → "仍要运行"

这是正常的，因为应用未签名。

---

## 🔧 常见问题

### Q: build_setup.bat 运行失败
**A:** 确保已安装 Inno Setup 6 并添加到 PATH

### Q: 提示找不到文件
**A:** 确保已运行 `flutter build windows --release`

### Q: 安装后无法运行
**A:** 安装 WebView2 Runtime

### Q: 如何修改版本号？
**A:** 编辑 `installer.iss` 中的 `AppVersion`

### Q: 如何修改应用名称？
**A:** 编辑 `installer.iss` 中的 `AppName`

---

## 📁 文件清单

```
D:\project\Genie-Studio-App\
├── installer.iss              # Inno Setup 脚本（核心文件）
├── build_setup.bat            # 一键构建脚本
├── check_inno.ps1             # 检查 Inno Setup 工具
├── LICENSE.txt                # 许可证文件
├── INSTALLER_README.md        # 详细说明文档
├── installer_assets/          # 安装程序资源目录
└── installer_output/          # 输出目录（自动生成）
    └── genie_review_assistant_setup_1.0.0.exe  # 安装程序
```

---

## 🎨 进阶定制

### 添加自定义图片

在 `installer_assets` 目录添加：
- `wizard_image.bmp` (164x314 像素) - 向导左侧图片
- `wizard_small.bmp` (55x55 像素) - 右上角小图标

### 修改安装路径

编辑 `installer.iss`：
```ini
DefaultDirName={autopf}\你的应用名称
```

### 添加开机自启动

取消 `installer.iss` 中的注释行

---

## 📞 需要帮助？

如果遇到问题，请检查：
1. Inno Setup 6 是否正确安装
2. Flutter 是否构建成功
3. 所有文件路径是否正确

---

## ✅ 完成！

按照上述步骤操作后，你将拥有一个专业的 Windows 安装程序，用户可以：
- 双击运行安装向导
- 选择安装路径
- 创建桌面快捷方式
- 完整卸载应用

**开始制作：** 双击 `build_setup.bat` 或查看详细文档 `INSTALLER_README.md`
