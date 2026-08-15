import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/utils/format_utils.dart';

/// 日志类型
enum LogType { info, success, error, warn, auto, pause }

/// 日志条目
class LogEntry {
  const LogEntry({
    required this.time,
    required this.message,
    required this.type,
  });

  final DateTime time;
  final String message;
  final LogType type;

  String get timeStr => FormatUtils.formatClock(time);
}

/// 日志状态
class LogState {
  const LogState({this.entries = const []});
  final List<LogEntry> entries;
}

/// 日志 Notifier
class LogNotifier extends StateNotifier<LogState> {
  LogNotifier() : super(const LogState());

  String _lastLog = '';
  DateTime? _lastLogTime;

  /// 无变化关键词（过滤重复的"无新内容"日志）
  static const _noChangePatterns = [
    '没有新的普通 EP',
    '没有新的',
    '无变化',
    '无需更新',
    '当前任务没有',
  ];

  void add(String message, LogType type) {
    final now = DateTime.now();
    // 相同消息 10 秒内不重复
    if (message == _lastLog &&
        _lastLogTime != null &&
        now.difference(_lastLogTime!).inMilliseconds < 10000) {
      return;
    }
    // auto 类型 5 秒内不重复
    if (type == LogType.auto &&
        _lastLogTime != null &&
        now.difference(_lastLogTime!).inMilliseconds < 5000) {
      return;
    }
    // 过滤无变化日志
    if (_noChangePatterns.any((p) => message.contains(p))) {
      return;
    }
    _lastLog = message;
    _lastLogTime = now;

    final entry = LogEntry(time: now, message: message, type: type);
    final newList = [...state.entries, entry];
    if (newList.length > AppConfig.maxLogCount) {
      final newEntries = newList.sublist(
        newList.length - AppConfig.maxLogCount,
      );
      state = LogState(entries: newEntries);
    } else {
      state = LogState(entries: newList);
    }
  }

  void info(String msg) => add(msg, LogType.info);
  void success(String msg) => add(msg, LogType.success);
  void error(String msg) => add(msg, LogType.error);
  void warn(String msg) => add(msg, LogType.warn);
  void auto(String msg) => add(msg, LogType.auto);
  void pause(String msg) => add(msg, LogType.pause);

  void clear() {
    state = const LogState();
  }
}

/// 日志 provider
final logProvider = StateNotifierProvider<LogNotifier, LogState>((ref) {
  return LogNotifier();
});
