# GitHub Release 发布指南

## 📋 发布步骤

### 1. 创建 Tag

在 GitHub 仓库页面：

1. 点击 "Releases" 标签
2. 点击 "Draft a new release" 按钮
3. 在 "Tag version" 输入：`v1.0.0`
4. 选择 "Create new tag: v1.0.0 on publish"

### 2. 填写 Release 信息

**Release title（标题）**：
```
v1.0.0
```

**Describe this release（描述）**：
复制 `RELEASE_NOTES.md` 文件中的内容

### 3. 上传附件

在 "Attach binaries" 部分上传以下文件：

1. **安装程序**：
   - 文件：`installer_output\zero_K-Genie_Setup_1.0.0.exe`
   - 说明：Windows 安装程序

2. **便携版**（可选）：
   - 文件：`dist\zero_K-Genie_Portable_1.0.0.zip`
   - 说明：免安装版本

### 4. 发布选项

- ☑️ Set as the latest release（设为最新版本）
- ☐ Set as a pre-release（预发布）
- ☐ Create a discussion for this release（创建讨论）

### 5. 发布

点击 "Publish release" 按钮

---

## 📝 Release 内容模板

```markdown
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
- **深色/浅色主题**：支持主题切换（开发中）

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
| Flutter | 3.12.2+ | 跨平台 UI 框架 |
| Dart | 3.0+ | 编程语言 |
| Riverpod | 2.5.1 | 状态管理 |
| GoRouter | 14.2.7 | 路由管理 |
| Dio | 5.7.0 | 网络请求 |
| WebView Windows | 0.4.0 | Windows WebView |
| Window Manager | 0.4.2 | 窗口管理 |
| SharedPreferences | 2.3.2 | 本地存储 |

---

## 📦 安装说明

### 方式一：使用安装程序（推荐）

1. 下载 `zero_K-Genie_Setup_1.0.0.exe`
2. 双击运行安装程序
3. 按照向导完成安装
4. 从桌面或开始菜单启动应用

### 方式二：便携版

1. 下载 `zero_K-Genie_Portable_1.0.0.zip`
2. 解压到任意目录
3. 双击 `zero_k_genie.exe` 运行

### 方式三：从源码构建

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
- 📝 [更新日志](https://github.com/Hongwei-name/Genie-Studio-App/releases)
- 💻 [源代码](https://github.com/Hongwei-name/Genie-Studio-App)

---

## 📸 界面预览

### 主界面
- macOS 风格的现代化界面
- 左侧导航栏
- 任务列表视图

### 配置页面
- 两列布局设计
- 登录功能
- 丰富的配置选项

### 任务列表
- 简洁的四列布局
- 一键打开 EP
- 预览首帧功能

---

## 🙏 致谢

感谢以下开源项目：

- [Flutter](https://flutter.dev/)
- [Riverpod](https://riverpod.dev/)
- [WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

**作者**: zero_K  
**版本**: v1.0.0  
**发布日期**: 2024年8月
```

---

## 🎯 快速发布清单

- [ ] 创建 Tag: `v1.0.0`
- [ ] 填写标题: `v1.0.0`
- [ ] 复制描述内容
- [ ] 上传安装程序附件
- [ ] 设置为最新版本
- [ ] 点击发布

---

## 📌 注意事项

1. **Tag 格式**：使用 `v` 前缀，如 `v1.0.0`
2. **版本号**：遵循语义化版本规范
3. **附件命名**：使用清晰的文件名
4. **描述内容**：包含完整的功能说明和安装指南
5. **系统要求**：明确说明运行环境

---

## 🚀 发布后

发布完成后，可以：

1. **分享链接**：将 Release 链接分享给用户
2. **更新文档**：更新 README.md 中的下载链接
3. **通知用户**：通过邮件或其他方式通知用户
4. **收集反馈**：关注 Issues 中的反馈

---

## 📚 相关文档

- [RELEASE_NOTES.md](RELEASE_NOTES.md) - Release 文档
- [README.md](README.md) - 项目说明
- [installer/QUICK_START.md](installer/QUICK_START.md) - 安装程序制作指南
