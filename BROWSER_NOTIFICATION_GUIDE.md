# 浏览器通知功能使用说明

## 📋 功能概述

当您在浏览器中完成标注操作时，油猴脚本会自动通知本地应用，应用的今日完成计数会自动加一。

---

## 🔧 安装步骤

### 1. 安装油猴脚本

1. 安装 [Tampermonkey](https://www.tampermonkey.net/) 浏览器扩展
2. 点击 Tampermonkey 图标 → "添加新脚本"
3. 将 `tampermonkey_script.js` 文件内容复制粘贴
4. 保存脚本（Ctrl+S）

### 2. 启动应用

1. 运行 `zero_K-Genie` 应用
2. 应用会自动启动浏览器通知服务（端口：18080）
3. 查看日志确认服务已启动

---

## 🎯 工作原理

```
浏览器标注成功 → 油猴脚本检测 → 发送通知到 localhost:18080 → 应用接收通知 → 计数加一
```

### 通信流程

1. **油猴脚本** 监听页面变化和按钮点击
2. 检测到标注成功后，发送 POST 请求到 `http://localhost:18080`
3. **应用** 的通知服务接收请求并处理
4. 调用 `StatsNotifier.addSuccess()` 增加今日完成数
5. 显示桌面通知

---

## 📡 通知接口

### 请求格式

```http
POST http://localhost:18080
Content-Type: application/json

{
    "type": "review_success",
    "episodeId": 12345,
    "taskId": 678,
    "message": "标注成功"
}
```

### 通知类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `review_success` | 标注成功 | `{"type": "review_success", "episodeId": 123}` |
| `review_failed` | 标注失败 | `{"type": "review_failed", "episodeId": 123, "message": "原因"}` |
| `ping` | 心跳检测 | `{"type": "ping"}` |

### 响应格式

```json
{
    "success": true,
    "message": "通知已接收"
}
```

---

## 🔍 调试方法

### 1. 查看浏览器控制台

1. 按 `F12` 打开开发者工具
2. 切换到 "Console" 标签
3. 查看 `[zero_K-Genie]` 开头的日志

### 2. 查看应用日志

1. 打开应用
2. 切换到 "日志" 页面
3. 查看浏览器通知相关日志

### 3. 测试通知服务

```powershell
# 测试心跳
Invoke-RestMethod -Uri http://localhost:18080 -Method POST -ContentType "application/json" -Body '{"type":"ping"}'

# 测试标注成功
Invoke-RestMethod -Uri http://localhost:18080 -Method POST -ContentType "application/json" -Body '{"type":"review_success","episodeId":12345}'
```

---

## ⚙️ 配置说明

### 油猴脚本配置

在脚本顶部修改 `CONFIG` 对象：

```javascript
const CONFIG = {
    // 本地通知服务地址
    notificationUrl: 'http://localhost:18080',
    // 是否启用调试日志
    debug: true,
    // ...
};
```

### 应用配置

通知服务端口在 `browser_notification_service.dart` 中定义：

```dart
static const int port = 18080;
```

---

## 🐛 常见问题

### Q: 通知没有发送成功

**检查项：**
1. 应用是否正在运行？
2. 日志中是否显示 "浏览器通知服务已启动"？
3. 浏览器控制台是否有错误信息？

**解决方案：**
```powershell
# 检查端口是否被占用
netstat -ano | findstr :18080

# 如果端口被占用，终止进程或修改端口
```

### Q: 标注成功但计数没有增加

**检查项：**
1. 浏览器控制台是否显示 "检测到标注成功"？
2. 应用日志是否显示 "浏览器标注成功"？
3. EP ID 是否已被处理过（去重机制）？

### Q: 油猴脚本不生效

**检查项：**
1. Tampermonkey 是否启用？
2. 脚本是否启用？
3. 网址是否匹配 `*://tgs-geniestudio.agibot.com/*`？

---

## 📝 更新日志

### v1.0.0 (2026-08-15)
- 初始版本
- 支持标注成功通知
- 支持桌面通知提醒
- 支持心跳检测

---

## 🔗 相关链接

- [项目主页](https://github.com/Hongwei-name/Genie-Studio-App)
- [问题反馈](https://github.com/Hongwei-name/Genie-Studio-App/issues)
- [Tampermonkey](https://www.tampermonkey.net/)

---

## 📄 许可证

MIT License

---

**作者**: zero_K
