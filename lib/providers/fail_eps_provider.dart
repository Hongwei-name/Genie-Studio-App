import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/episode.dart';
import '../data/repositories/review_repository.dart';
import 'app_providers.dart';
import 'log_provider.dart';

/// 失败 EP 扫描状态
class FailEpsState {
  const FailEpsState({
    this.failedEps = const [],
    this.isLoading = false,
    this.loaded = false,
    this.progress = 0,
    this.progressText = '',
    this.lastScanResult,
  });

  final List<FailedEpisode> failedEps;
  final bool isLoading;
  final bool loaded;

  /// 扫描进度 0-100
  final int progress;
  final String progressText;
  final ScanResult? lastScanResult;

  FailEpsState copyWith({
    List<FailedEpisode>? failedEps,
    bool? isLoading,
    bool? loaded,
    int? progress,
    String? progressText,
    ScanResult? lastScanResult,
    bool clearProgressText = false,
  }) {
    return FailEpsState(
      failedEps: failedEps ?? this.failedEps,
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      progress: progress ?? this.progress,
      progressText:
          clearProgressText ? '' : (progressText ?? this.progressText),
      lastScanResult: lastScanResult ?? this.lastScanResult,
    );
  }
}

/// 失败 EP 扫描 Notifier
class FailEpsNotifier extends StateNotifier<FailEpsState> {
  FailEpsNotifier(this._ref) : super(const FailEpsState());

  final Ref _ref;

  ReviewRepository get _repo => _ref.read(reviewRepositoryProvider);
  int get _concurrency => _ref.read(settingsProvider).concurrency;
  String get _screener => _ref.read(settingsProvider).screener;

  /// 扫描失败 EP
  /// [isAutoRefresh] 自动刷新时增量更新
  Future<void> scan({bool isAutoRefresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      progress: 0,
      progressText: '开始扫描...',
    );

    if (!isAutoRefresh) {
      state = state.copyWith(failedEps: []);
    }

    final prevKeys = isAutoRefresh
        ? state.failedEps.map((e) => e.key).toSet()
        : <String>{};

    _ref.read(logProvider.notifier).info(
          '开始获取验收失败EP（并发$_concurrency路）'
          '${_screener.isNotEmpty ? '，初筛人筛选：$_screener' : ''}',
        );

    try {
      final result = await _repo.scanFailedEpisodes(
        concurrency: _concurrency,
        screener: _screener,
        onProgress: (percent, text) {
          state = state.copyWith(progress: percent, progressText: text);
        },
      );

      // 自动刷新时增量更新
      final newFailedEps = <FailedEpisode>[];
      if (isAutoRefresh) {
        // 保留旧数据中仍存在的，追加新的
        final newKeys = result.failedEpisodes.map((e) => e.key).toSet();
        newFailedEps.addAll(
          state.failedEps.where((e) => newKeys.contains(e.key)),
        );
        for (final ep in result.failedEpisodes) {
          if (!prevKeys.contains(ep.key)) {
            newFailedEps.add(ep);
          }
        }
      } else {
        newFailedEps.addAll(result.failedEpisodes);
      }

      var logMsg = 'EP扫描完成：共 ${result.totalEps} 条EP，'
          '${result.failedEpsCount} 条验收失败';
      if (result.selfReviewExcluded > 0) {
        logMsg += '（排除 ${result.selfReviewExcluded} 条自审）';
      }
      logMsg += '，${result.filteredCount} 条符合筛选';
      _ref.read(logProvider.notifier).info(logMsg);

      state = FailEpsState(
        failedEps: newFailedEps,
        isLoading: false,
        loaded: true,
        progress: 100,
        progressText: '完成',
        lastScanResult: result,
      );

      _ref.read(logProvider.notifier).success(
            '验收失败EP获取完成：扫描 ${result.taskCount} 任务 / '
            '${result.jobCount} Job，发现 ${newFailedEps.length} 条',
          );

      // 1.5 秒后清空进度文本
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          state = state.copyWith(clearProgressText: true);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        progress: 0,
        progressText: '',
      );
      _ref.read(logProvider.notifier).error('获取验收失败EP失败: $e');
    }
  }

  /// 重置缓存并重新扫描
  Future<void> rescan() async {
    state = state.copyWith(failedEps: [], loaded: false);
    _ref.read(logProvider.notifier).info('已重置验收失败EP缓存，开始重新扫描...');
    await scan();
  }
}

/// 失败 EP provider
final failEpsProvider =
    StateNotifierProvider<FailEpsNotifier, FailEpsState>((ref) {
  return FailEpsNotifier(ref);
});
