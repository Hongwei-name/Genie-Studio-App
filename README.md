# zero_K-Genie

智元标注审核助手桌面端 - 解决并发能力不足及功能弱的问题

## 简介

zero_K-Genie 是一款基于 Flutter 开发的 Windows 桌面应用程序，用于智元标注审核工作。它提供了高效的并发处理能力和丰富的功能特性。

## 功能特性

- ✅ macOS 风格的现代化界面
- ✅ 任务管理和批量处理
- ✅ WebView 内嵌审核页面
- ✅ 实时统计和监控
- ✅ 本地配置管理
- ✅ 日志查看和错误追踪

## 技术栈

- **框架**: Flutter 3.12.2+
- **状态管理**: Riverpod
- **路由**: GoRouter
- **网络**: Dio
- **本地存储**: SharedPreferences
- **窗口管理**: window_manager

## 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/Hongwei-name/Genie-Studio-App.git

# 进入项目目录
cd Genie-Studio-App

# 获取依赖
flutter pub get

# 运行应用
flutter run -d windows

# 构建 Release 版本
flutter build windows --release
```

### 使用安装程序

下载 `zero_K-Genie_Setup_1.0.0.exe` 并运行安装程序。

## 项目结构

```
Genie-Studio-App/
├── lib/                          # 源代码
│   ├── app.dart                 # 应用入口
│   ├── main.dart                # 主函数
│   ├── core/                    # 核心功能
│   ├── data/                    # 数据层
│   ├── features/                # 功能模块
│   └── providers/               # 状态管理
├── installer/                   # 安装程序
├── docs/                        # 文档
├── windows/                     # Windows 平台文件
└── pubspec.yaml                 # 依赖配置
```

## 开发

### 环境要求

- Flutter SDK 3.12.2+
- Windows 10/11
- Visual Studio 2019+ (C++ 开发工具)

### 运行开发环境

```bash
flutter run -d windows
```

### 构建发布版本

```bash
flutter build windows --release
```

### 生成安装程序

```bash
# 方法1: 使用 PowerShell
.\installer\Generate-Setup.ps1

# 方法2: 使用批处理
.\installer\生成安装程序.bat
```

## 许可证

MIT License - 详见 [LICENSE.txt](LICENSE.txt)

## 作者

**zero_K**

## 链接

- [GitHub 仓库](https://github.com/Hongwei-name/Genie-Studio-App)
- [问题反馈](https://github.com/Hongwei-name/Genie-Studio-App/issues)
