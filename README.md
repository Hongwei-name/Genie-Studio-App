# 智元标注审核助手 - 桌面端

基于 Flutter 的 Windows 桌面应用，替代原油猴脚本（智元标注审核助手），解决浏览器并发能力不足及功能弱的问题。

## 核心特性

- **高并发扫描**：可配置 1-64 路并发（浏览器受限于 6-8），显著提升任务/Job/EP 扫描速度
- **Token 配置**：直接在配置页填入 Cookie，桌面端原生调用 API，无需浏览器登录
- **待审核 EP 管理**：任务 → Job → EP 三级展开，一键打开审核页
- **验收失败 EP 扫描**：全量并发扫描所有任务，按初筛人筛选，自审排除
- **自动刷新**：可配置刷新间隔，自动发现新 EP 并可选自动打开
- **EP 打开方式**：系统浏览器 / 应用内 WebView（WebView2，注入 Cookie 免登录）
- **今日统计**：完成数 + 视频时长（按 30fps 换算）
- **iOS 风格 UI**：Cupertino 风格，圆角简洁，无杂乱配色

## 构建环境要求

- Flutter >= 3.12.2
- Dart >= 3.12.2
- Windows 10 及以上
- **Windows 开发者模式**（构建插件需要符号链接支持）
  - 打开方式：`start ms-settings:developers` → 启用「开发者模式」
- CMake 及 Visual Studio Build Tools（C++ 桌面开发工作负载）

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 分析检查
flutter analyze

# 运行测试
flutter test

# Debug 模式运行
flutter run -d windows

# Release 模式构建
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/`。

## Windows 发布签名

企业 Windows 策略可能拒绝加载未签名的 Flutter exe 或插件 DLL。发布时必须使用企业信任链中的代码签名证书；自签名证书不能绕过 WDAC 或 Code Integrity 策略。

先将证书和私钥安装到当前用户的个人证书存储，然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sign-windows-release.ps1 -CertificateThumbprint YOUR_40_CHAR_THUMBPRINT
```

脚本会构建 Release 包，对 exe 和全部 DLL 添加 SHA-256 签名及时间戳，并逐个验证签名。证书必须包含可用私钥，并且其根证书和发布者证书必须被目标计算机的企业策略信任。

## 配置说明

首次使用需前往「配置」页面：

1. **Token (Cookie)**：从浏览器开发者工具复制完整 Cookie 字符串
2. **刷新频率**：任务列表自动刷新间隔（秒，0=暂停）
3. **并发数**：1-64，推荐 16-32
4. **EP 打开方式**：浏览器 / WebView
5. **自动打开新 EP**：仅自动打开未打开、非验收失败的普通 EP
6. **初筛人筛选**：验收失败 EP 按初筛人用户名筛选

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # 根 Widget
├── core/
│   ├── config/app_config.dart     # 全局常量 + EpOpenMode 枚举
│   ├── network/api_client.dart    # Dio 封装（Cookie 拦截器 + 连接池）
│   ├── theme/app_theme.dart       # iOS 风格主题
│   └── utils/
│       ├── concurrency_utils.dart # 并发池工具
│       └── format_utils.dart      # 时间/格式化工具
├── data/
│   ├── models/                    # Task / Job / Episode / Resource / AppSettings
│   ├── repositories/              # ReviewRepository（API + 并发逻辑）
│   └── storage/config_storage.dart # SharedPreferences 持久化
├── providers/                     # Riverpod 状态管理
│   ├── app_providers.dart         # 配置 + Repository provider
│   ├── tasks_provider.dart        # 任务列表 + EP 打开请求
│   ├── fail_eps_provider.dart     # 验收失败 EP 扫描
│   ├── refresh_provider.dart      # 自动刷新定时器
│   ├── stats_provider.dart        # 今日统计
│   └── log_provider.dart          # 操作日志
└── features/
    ├── shell/home_shell.dart      # 主框架（导航 + 顶部统计栏）
    ├── tasks/tasks_page.dart      # 待审核 EP 页
    ├── fail_eps/fail_eps_page.dart # 验收失败 EP 页
    ├── logs/logs_page.dart        # 操作日志页
    ├── stats/stats_page.dart      # 今日统计页
    ├── config/config_page.dart    # 配置页（含 Token 配置）
    └── webview/webview_page.dart  # 应用内 WebView 页
```

## 技术栈

| 模块       | 选型                  |
| ---------- | --------------------- |
| 框架       | Flutter (Cupertino)   |
| 状态管理   | Riverpod              |
| 网络请求   | Dio（连接池 + 拦截器）|
| 本地存储   | SharedPreferences     |
| 系统浏览器 | url_launcher          |
| 应用内 WebView | webview_windows (WebView2) |
| 国际化     | intl                  |

## 与原脚本对比

| 能力           | 原油猴脚本           | 桌面端                     |
| -------------- | -------------------- | -------------------------- |
| 并发数         | 6-8（浏览器限制）    | 1-64（可配置）             |
| 存储           | GM_getValue/GM_setValue | SharedPreferences       |
| EP 打开        | GM_openInTab/window.open | 系统浏览器 / WebView2   |
| UI             | DOM 注入             | 原生 Flutter Cupertino     |
| 认证           | 浏览器 Cookie        | Cookie 拦截器注入          |
| 失败 EP 扫描   | 串行 + 有限并发      | 全量可配置并发             |
