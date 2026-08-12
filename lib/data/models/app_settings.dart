import '../../core/config/app_config.dart';

/// EP 打开方式
export '../../core/config/app_config.dart' show EpOpenMode;

/// 应用配置模型
/// 对齐原脚本 Store 中的所有配置项
class AppSettings {
  const AppSettings({
    this.cookie = '',
    this.refreshInterval = AppConfig.defaultRefreshInterval,
    this.resumeRefreshInterval = AppConfig.defaultRefreshInterval,
    this.autoOpen = false,
    this.screener = '',
    this.showAllJobs = false,
    this.concurrency = AppConfig.defaultConcurrency,
    this.epOpenMode = EpOpenMode.browser,
  });

  /// Cookie 字符串（从浏览器复制，如 "session=xxx; token=yyy"）
  final String cookie;

  /// 任务列表刷新间隔（毫秒），0 表示暂停
  final int refreshInterval;

  final int resumeRefreshInterval;

  /// 自动打开新 EP
  final bool autoOpen;

  /// 初筛人筛选（用户名，如 zhoujun）
  final String screener;

  /// 显示所有 Job（含无待审 EP 的）
  final bool showAllJobs;

  /// 并发数（1-64）
  final int concurrency;

  /// EP 审核页打开方式
  final EpOpenMode epOpenMode;

  /// 是否暂停刷新
  bool get isPaused => refreshInterval <= 0;

  /// 刷新间隔（秒）
  int get refreshIntervalSeconds => refreshInterval ~/ 1000;

  AppSettings copyWith({
    String? cookie,
    int? refreshInterval,
    int? resumeRefreshInterval,
    bool? autoOpen,
    String? screener,
    bool? showAllJobs,
    int? concurrency,
    EpOpenMode? epOpenMode,
  }) {
    return AppSettings(
      cookie: cookie ?? this.cookie,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      resumeRefreshInterval:
          resumeRefreshInterval ?? this.resumeRefreshInterval,
      autoOpen: autoOpen ?? this.autoOpen,
      screener: screener ?? this.screener,
      showAllJobs: showAllJobs ?? this.showAllJobs,
      concurrency: concurrency ?? this.concurrency,
      epOpenMode: epOpenMode ?? this.epOpenMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'cookie': cookie,
        'refreshInterval': refreshInterval,
        'resumeRefreshInterval': resumeRefreshInterval,
        'autoOpen': autoOpen,
        'screener': screener,
        'showAllJobs': showAllJobs,
        'concurrency': concurrency,
        'epOpenMode': epOpenMode.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        cookie: (json['cookie'] as String?) ?? '',
        refreshInterval: (json['refreshInterval'] as num?)?.toInt() ??
            AppConfig.defaultRefreshInterval,
        resumeRefreshInterval:
            (json['resumeRefreshInterval'] as num?)?.toInt() ??
                ((json['refreshInterval'] as num?)?.toInt() ??
                    AppConfig.defaultRefreshInterval),
        autoOpen: (json['autoOpen'] as bool?) ?? false,
        screener: (json['screener'] as String?) ?? '',
        showAllJobs: (json['showAllJobs'] as bool?) ?? false,
        concurrency: (json['concurrency'] as num?)?.toInt() ??
            AppConfig.defaultConcurrency,
        epOpenMode: EpOpenMode.values.firstWhere(
          (m) => m.name == (json['epOpenMode'] as String?),
          orElse: () => EpOpenMode.browser,
        ),
      );
}
