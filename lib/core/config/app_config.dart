/// 全局配置常量
/// 对齐原脚本 CONFIG 对象
class AppConfig {
  AppConfig._();

  /// API 基础地址
  static const String apiBase = 'https://tgs-geniestudio.agibot.com';

  /// WebView 注入 Cookie 时使用的登录入口
  static const String webViewLoginUrl =
      'https://tgs-geniestudio.agibot.com/login/gxcy';

  /// 默认刷新间隔（毫秒）
  static const int defaultRefreshInterval = 5000;

  /// 标注成功去抖动（毫秒）
  static const int successDebounce = 3000;

  /// 最大日志条数
  static const int maxLogCount = 200;

  /// 任务列表分页大小
  static const int taskPageSize = 20;

  /// Job 分页大小
  static const int jobPageSize = 10;

  /// EP 分页大小
  static const int epPageSize = 10;

  /// 默认并发数
  static const int defaultConcurrency = 16;

  /// 最大并发数上限
  static const int maxConcurrency = 64;

  /// 最小并发数
  static const int minConcurrency = 1;

  /// 最大已打开EP记录数
  static const int maxOpenedEps = 500;

  /// 帧率（用于视频时长计算）
  static const int framesPerSecond = 30;

  /// 请求超时（毫秒）
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 15000;

  /// 重试配置：网络错误/超时/429 自动重试
  static const int maxRetry = 2;
  static const int retryBaseDelay = 500; // 500ms, 1000ms 指数退避

  /// 单任务详情加载的并发上限（避免一次性并发过多被限流）
  static const int taskDetailConcurrency = 4;

  /// 预估任务列表最大页数
  static const int maxTaskPageEstimate = 20;

  /// API 响应码：登录失效
  static const int codeUnauthorized = 40101;

  /// API 响应码：成功
  static const int codeSuccess = 0;
}

/// EP 审核页打开方式
enum EpOpenMode {
  /// 系统默认浏览器
  browser,

  /// 应用内 WebView
  webview,
}

/// 页面路由名称
class AppRoute {
  AppRoute._();

  static const String tasks = '/tasks';
  static const String failEps = '/failEps';
  static const String logs = '/logs';
  static const String stats = '/stats';
  static const String config = '/config';
  static const String webview = '/webview';
}
