import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'fail_eps_provider.dart';
import 'tasks_provider.dart';

/// 自动刷新 Notifier
/// 对齐原脚本 restartRefreshTimer
class RefreshNotifier extends StateNotifier<bool> {
  RefreshNotifier(this._ref) : super(false);

  final Ref _ref;
  Timer? _timer;

  /// 当前是否在刷新中
  bool get isRunning => _timer != null;

  /// 启动定时刷新
  void start() {
    final interval = _ref.read(settingsProvider).refreshInterval;
    if (interval <= 0) {
      stop();
      return;
    }
    stop();
    _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (!_ref.read(settingsProvider).isPaused) {
        _ref.read(tasksProvider.notifier).fetchTasks(isAutoRefresh: true);
        // 失败 EP 已加载时静默更新
        if (_ref.read(failEpsProvider).loaded) {
          _ref.read(failEpsProvider.notifier).scan(isAutoRefresh: true);
        }
      }
    });
    state = true;
  }

  /// 停止定时刷新
  void stop() {
    _timer?.cancel();
    _timer = null;
    state = false;
  }

  /// 重启（配置变更时调用）
  void restart() {
    if (_ref.read(settingsProvider).isPaused) {
      stop();
    } else {
      start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 自动刷新 provider
final refreshProvider =
    StateNotifierProvider<RefreshNotifier, bool>((ref) {
  return RefreshNotifier(ref);
});
