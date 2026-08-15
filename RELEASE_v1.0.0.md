# zero_K-Genie v1.0.0

智元标注审核助手桌面端 - 解决并发能力不足及功能弱的问题

## ✨ 功能特性

### 🎯 核心功能
- **任务管理**：批量获取和管理审核任务
- **并发控制**：支持 1-10 并发数设置
- **自动打开**：自动打开待审核的 EP
- **WebView 内嵌**：在应用内打开审核页面
- **实时统计**：今日完成数和视频时长统计

### 🎨 界面特性
- **macOS 风格**：现代化的毛玻璃风格界面
- **交通灯按钮**：原生 macOS 窗口控制按钮
- **响应式布局**：自适应窗口大小
- **统一圆角**：所有弹出窗口统一圆角样式

### ⚙️ 配置功能
- **Cookie 认证**：支持手动输入和自动获取
- **登录功能**：一键登录获取 Cookie
- **刷新设置**：可配置自动刷新频率
- **初筛人筛选**：支持按初筛人过滤任务
- **EP 打开方式**：浏览器或 WebView 两种模式

### 📊 数据管理
- **验收失败 EP**：单独展示和管理
- **日志系统**：完整的操作日志记录
- **统计面板**：今日完成情况统计
- **数据持久化**：本地配置和数据存储

---

## 🛠️ 技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| Flutter | 3.44.8 | 跨平台 UI 框架 |
| Dart | 3.12.2 | 编程语言 |
| Riverpod | 2.6.1 | 状态管理 |
| GoRouter | 14.8.1 | 路由管理 |
| Dio | 5.11.0 | 网络请求 |
| WebView Windows | 0.4.0 | Windows WebView |
| Window Manager | 0.4.3 | 窗口管理 |

---

## 📦 安装说明

### 方式一：使用安装程序（推荐）

1. 下载 `zero_K-Genie_Setup_1.0.0.exe`
2. 双击运行安装程序
3. 选择安装语言（简体中文/English）
4. 按照向导完成安装
5. 从桌面或开始菜单启动应用

### 方式二：便携版

1. 下载 `build\windows\x64\runner\Release\` 文件夹
2. 双击 `zero_k_genie.exe` 运行

---

## 💻 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 1809+ 或 Windows 11 |
| 架构 | x64 |
| 运行时 | WebView2 Runtime |
| 内存 | 建议 4GB+ |
| 磁盘空间 | 100MB+ |

### 依赖组件

- **WebView2 Runtime**：用于内嵌网页功能
  - 下载地址：https://developer.microsoft.com/en-us/microsoft-edge/webview2/
  - Windows 11 通常已预装

---

## 🔗 相关链接

- 📖 [项目文档](https://github.com/Hongwei-name/Genie-Studio-App)
- 🐛 [问题反馈](https://github.com/Hongwei-name/Genie-Studio-App/issues)
- 💻 [源代码](https://github.com/Hongwei-name/Genie-Studio-App)

---

## 📄 许可证

MIT License

---

**作者**: zero_K  
**版本**: v1.0.0  
**发布日期**: 2026年8月
