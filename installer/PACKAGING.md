# 智元标注审核助手 - 打包说明

## 📦 打包方式

本项目提供两种打包方式：

### 方式1：MSIX 安装包（推荐）

**优点：**
- 微软官方推荐的打包格式
- 支持自动更新
- 标准的安装/卸载流程
- 支持 Windows 10/11

**打包步骤：**

1. **方法A：使用批处理脚本（最简单）**
   ```
   双击运行 build_installer.bat
   ```

2. **方法B：使用 PowerShell 脚本**
   ```powershell
   cd D:\project\Genie-Studio-App
   .\build_installer.ps1
   ```

3. **方法C：手动命令行**
   ```powershell
   cd D:\project\Genie-Studio-App
   flutter clean
   flutter pub get
   flutter build windows --release
   dart run msix:create
   ```

**输出文件：**
- 位置：`build\windows\x64\runner\Release\genie_review_assistant.msix`
- 双击即可安装

---

### 方式2：便携版 ZIP 包

**优点：**
- 无需安装，解压即用
- 适合绿色软件分发
- 方便在U盘携带

**打包步骤：**

```powershell
cd D:\project\Genie-Studio-App
.\build_portable.ps1
```

**输出文件：**
- 位置：`dist\genie_review_assistant_portable_*.zip`

---

## 🎯 分发建议

### 对于普通用户（推荐 MSIX）
1. 发送 `.msix` 文件
2. 用户双击安装
3. 应用会出现在开始菜单

### 对于技术人员（推荐便携版）
1. 发送 `.zip` 文件
2. 解压到任意文件夹
3. 直接运行 exe 文件

---

## ⚠️ 注意事项

1. **系统要求**：Windows 10 1809 及以上版本
2. **依赖项**：需要安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)
3. **签名**：当前未签名，首次运行可能会有安全警告
   - 右键 → 属性 → 解除锁定
   - 或者点击"更多信息" → "仍要运行"

---

## 🔧 自定义配置

### 修改应用信息

编辑 `pubspec.yaml` 中的 `msix_config` 部分：

```yaml
msix_config:
  display_name: 智元标注审核助手      # 显示名称
  publisher_display_name: GenieStudio  # 发布者名称
  identity_name: com.geniestudio.reviewassistant  # 应用标识
  msix_version: 1.0.0.0               # 版本号
  logo_path: windows\runner\resources\app_icon.ico  # 图标路径
```

### 修改图标

替换 `windows\runner\resources\app_icon.ico` 文件

---

## 📋 文件清单

打包后的 Release 目录包含以下文件：

```
Release/
├── genie_review_assistant.exe    # 主程序
├── flutter_windows.dll           # Flutter 运行时
├── data/                         # 应用数据
├── WebView2Loader.dll            # WebView2 加载器
├── webview_windows_plugin.dll    # WebView 插件
├── window_manager_plugin.dll     # 窗口管理插件
└── 其他依赖 DLL...
```

所有文件都需要一起分发！

---

## 🐛 常见问题

### Q: 打包时提示找不到 Flutter
A: 确保已安装 Flutter SDK 并添加到 PATH 环境变量

### Q: 安装后无法运行
A: 检查是否安装了 WebView2 Runtime

### Q: 如何修改版本号？
A: 修改 `pubspec.yaml` 中的 `version` 字段和 `msix_config` 中的 `msix_version`

### Q: 如何签名？
A: 需要购买代码签名证书，或使用自签名证书（仅限测试）
