# 智元标注审核助手 - 安装程序制作指南

## 📦 生成安装程序

### 方法1：一键生成（推荐）

**双击运行：**
```
D:\project\Genie-Studio-App\build_setup.bat
```

**自动完成：**
1. ✅ 检查 Inno Setup 是否安装
2. ✅ 构建 Flutter Release 版本
3. ✅ 生成专业的安装程序

**输出文件：**
```
installer_output\genie_review_assistant_setup_1.0.0.exe
```

---

### 方法2：手动制作

#### 步骤1：安装 Inno Setup 6

1. 访问官网：https://jrsoftware.org/isinfo.php
2. 下载 Inno Setup 6
3. 安装时选择 "ChineseSimplified" 语言包

#### 步骤2：构建 Flutter 应用

```powershell
cd D:\project\Genie-Studio-App
flutter clean
flutter pub get
flutter build windows --release
```

#### 步骤3：生成安装程序

1. 打开 `installer.iss` 文件（用 Inno Setup 编辑器）
2. 点击菜单 "构建" → "编译" 或按 F9
3. 等待编译完成

---

## 🎯 安装程序功能

生成的安装程序包含以下功能：

### ✨ 安装向导
- 欢迎界面
- 许可证协议
- 选择安装路径（默认：`C:\Program Files\智元标注审核助手`）
- 选择附加任务：
  - ✅ 创建桌面快捷方式
  - ☐ 创建快速启动栏图标
- 准备安装
- 安装进度
- 安装完成（可选立即运行）

### 🗑️ 完整卸载
- 通过 "控制面板" → "程序和功能" 卸载
- 自动删除所有文件
- 清理注册表

### 📋 其他特性
- 自动检测 WebView2 Runtime
- 支持中文界面
- 自动创建开始菜单
- 支持文件关联（可选）

---

## 📤 分发给用户

### 发送文件
```
genie_review_assistant_setup_1.0.0.exe
```

### 用户操作
1. 双击运行安装程序
2. 按照向导提示操作
3. 安装完成后从桌面或开始菜单启动

---

## 🔧 自定义配置

### 修改应用信息

编辑 `installer.iss` 文件：

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

在 `installer_assets` 目录添加：
- `wizard_image.bmp` - 安装向导左侧图片（164x314 像素）
- `wizard_small.bmp` - 安装向导右上角图片（55x55 像素）

---

## ⚠️ 注意事项

1. **Inno Setup 6** 必须安装才能编译脚本
2. **WebView2 Runtime** 用户需要安装才能运行应用
   - 安装程序会自动提示下载
   - 或者用户自行安装：https://developer.microsoft.com/en-us/microsoft-edge/webview2/

3. **数字签名**（可选）
   - 当前未签名，用户可能看到安全警告
   - 生产环境建议购买代码签名证书

---

## 📁 文件清单

```
D:\project\Genie-Studio-App\
├── installer.iss              # Inno Setup 脚本
├── build_setup.bat            # 一键构建脚本
├── LICENSE.txt                # 许可证文件
├── installer_assets/          # 安装程序资源
│   ├── wizard_image.bmp       # 向导图片（可选）
│   └── wizard_small.bmp       # 小图标（可选）
└── installer_output/          # 输出目录
    └── genie_review_assistant_setup_1.0.0.exe  # 安装程序
```

---

## 🐛 常见问题

### Q: 提示找不到 Inno Setup
**A:** 需要先安装 Inno Setup 6：https://jrsoftware.org/isinfo.php

### Q: 编译时提示找不到文件
**A:** 确保已运行 `flutter build windows --release`

### Q: 安装后无法运行
**A:** 用户需要安装 WebView2 Runtime

### Q: 如何修改版本号？
**A:** 修改 `installer.iss` 中的 `AppVersion` 和 `OutputBaseFilename`

### Q: 如何添加桌面快捷方式？
**A:** 默认已启用，在安装向导中勾选 "创建桌面快捷方式"

---

## 🎨 高级定制

### 添加开机自启动

在 `installer.iss` 的 `[Registry]` 部分取消注释：
```ini
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "智元标注审核助手"; \
    ValueData: """{app}\genie_review_assistant.exe"""; \
    Flags: uninsdeletevalue
```

### 添加协议关联

在 `[Registry]` 部分添加：
```ini
Root: HKA; Subkey: "Software\Classes\genie-review"; \
    ValueType: string; ValueName: ""; \
    ValueData: "URL:智元标注审核助手协议"; \
    Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\genie-review"; \
    ValueType: string; ValueName: "URL Protocol"; \
    ValueData: ""
Root: HKA; Subkey: "Software\Classes\genie-review\shell\open\command"; \
    ValueType: string; ValueName: ""; \
    ValueData: """{app}\genie_review_assistant.exe"" ""%1"""
```

---

## 📝 生成效果预览

安装程序运行后会显示：

```
┌─────────────────────────────────────┐
│    智元标注审核助手 安装向导         │
├─────────────────────────────────────┤
│  欢迎使用 智元标注审核助手 安装向导  │
│                                     │
│  本向导将引导您完成安装。           │
│                                     │
│  [下一步]  [取消]                   │
└─────────────────────────────────────┘
```

用户可以：
- 选择安装路径
- 创建桌面快捷方式
- 查看许可证协议
- 完成安装后启动应用
