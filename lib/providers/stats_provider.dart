import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/format_utils.dart';
import '../data/storage/config_storage.dart';
import 'app_providers.dart';

/// 统计状态
class StatsState {
  const StatsState({
    this.todayCount = 0,
    this.todayFrames = 0,
  });

  final int todayCount;
  final int todayFrames;

  String get timeStr => FormatUtils.formatTime(todayFrames);
  String get timeShort => FormatUtils.formatTimeShort(todayFrames);

  StatsState copyWith({int? todayCount, int? todayFrames}) {
    return StatsState(
      todayCount: todayCount ?? this.todayCount,
      todayFrames: todayFrames ?? this.todayFrames,
    );
  }
}

/// 统计 Notifier
class StatsNotifier extends StateNotifier<StatsState> {
  StatsNotifier(this._storage) : super(const StatsState());

  final ConfigStorage _storage;

  /// 从存储加载
  void load() {
    state = StatsState(
      todayCount: _storage.todayCompleteCount(),
      todayFrames: _storage.todayFrames(),
    );
  }

  /// 增加今日完成数（带去抖动）
  DateTime? _lastSuccessTime;
  Future<bool> addSuccess() async {
    final now = DateTime.now();
    if (_lastSuccessTime != null &&
        now.difference(_lastSuccessTime!).inMilliseconds < 3000) {
      return false;
    }
    _lastSuccessTime = now;
    await _storage.incrementTodayCount();
    state = state.copyWith(todayCount: state.todayCount + 1);
    return true;
  }

  /// 增加今日帧数
  Future<void> addFrames(int frames) async {
    if (frames <= 0) return;
    await _storage.addTodayFrames(frames);
    state = state.copyWith(todayFrames: state.todayFrames + frames);
  }

  /// 重置今日统计
  Future<void> reset() async {
    await _storage.resetTodayStats();
    state = const StatsState();
  }
}

/// 统计 provider
final statsProvider = StateNotifierProvider<StatsNotifier, StatsState>((ref) {
  final storage = ref.watch(configStorageProvider);
  final notifier = StatsNotifier(storage);
  Future.microtask(() => notifier.load());
  return notifier;
});
