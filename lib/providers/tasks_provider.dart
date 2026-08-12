import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/concurrency_utils.dart';
import '../core/utils/format_utils.dart';
import '../data/models/episode.dart';
import '../data/models/job.dart';
import '../data/models/task.dart';
import '../data/repositories/review_repository.dart';
import '../data/storage/config_storage.dart';
import 'app_providers.dart';
import 'log_provider.dart';
import 'stats_provider.dart';

/// 任务列表状态
class TasksState {
  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.jobsByTask = const {},
    this.epsByJob = const {},
    this.openedEpKeys = const {},
    this.previewUrls = const {},
    this.previewNullKeys = const {},
    this.loadingTasks = const {},
    this.taskErrors = const {},
    this.lastUpdated,
  });

  final List<Task> tasks;
  final bool isLoading;
  final String? error;

  /// taskId -> jobs
  final Map<int, List<Job>> jobsByTask;

  /// "taskId_jobId" -> episodes
  final Map<String, List<Episode>> epsByJob;

  /// 今日已打开的 EP key
  final Set<String> openedEpKeys;

  /// "taskId_jobId" -> 首帧预览 URL
  final Map<String, String> previewUrls;

  /// 已查询过但无预览的 key（避免重复请求）
  final Set<String> previewNullKeys;

  /// 正在加载详情（Job + EP）的 taskId 集合
  final Set<int> loadingTasks;

  /// 按任务的错误信息（UI 展示重试入口）
  final Map<int, String> taskErrors;

  final DateTime? lastUpdated;

  int get totalPendingCount =>
      tasks.fold(0, (sum, t) => sum + t.notCheckCount);

  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    Map<int, List<Job>>? jobsByTask,
    Map<String, List<Episode>>? epsByJob,
    Set<String>? openedEpKeys,
    Map<String, String>? previewUrls,
    Set<String>? previewNullKeys,
    Set<int>? loadingTasks,
    Map<int, String>? taskErrors,
    DateTime? lastUpdated,
    bool clearError = false,
    bool clearTaskError = false,
    int? clearTaskErrorId,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      jobsByTask: jobsByTask ?? this.jobsByTask,
      epsByJob: epsByJob ?? this.epsByJob,
      openedEpKeys: openedEpKeys ?? this.openedEpKeys,
      previewUrls: previewUrls ?? this.previewUrls,
      previewNullKeys: previewNullKeys ?? this.previewNullKeys,
      loadingTasks: loadingTasks ?? this.loadingTasks,
      taskErrors: clearTaskError
          ? (clearTaskErrorId != null
              ? (Map<int, String>.from(this.taskErrors)..remove(clearTaskErrorId))
              : const <int, String>{})
          : (taskErrors ?? this.taskErrors),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 任务列表 Notifier
///
/// 分阶段加载策略：
/// 1. fetchTasks 只拉取任务列表（轻量，避免被限流）
/// 2. 展开任务时调用 loadTaskDetail 拉取该任务的 Job + 所有 Job 的待审 EP
/// 3. 单任务刷新 refreshTask 清除缓存重新加载
/// 4. 错误按任务记录，UI 展示重试入口
class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier(this._ref) : super(const TasksState());

  final Ref _ref;

  /// 已展开的任务 ID 集合（由 UI 层同步，用于自动刷新后重新加载）
  final Set<int> _expandedTaskIds = {};

  ReviewRepository get _repo => _ref.read(reviewRepositoryProvider);
  ConfigStorage get _storage => _ref.read(configStorageProvider);
  int get _concurrency => _ref.read(settingsProvider).concurrency;
  bool get _autoOpen => _ref.read(settingsProvider).autoOpen;
  bool get _isPaused => _ref.read(settingsProvider).isPaused;

  /// 获取所有任务（只拉任务列表，不拉 Job/EP）
  Future<void> fetchTasks({bool isAutoRefresh = false}) async {
    if (state.isLoading || _isPaused) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tasks = await _repo.fetchAllTasks(concurrency: _concurrency);
      tasks.sort((a, b) => b.notCheckCount.compareTo(a.notCheckCount));

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        lastUpdated: DateTime.now(),
        clearError: true,
      );

      // 自动刷新后，重新加载已展开任务的详情（获取最新 EP）
      final expandedTaskIds = List<int>.from(_expandedTaskIds);
      for (final taskId in expandedTaskIds) {
        await loadTaskDetail(taskId, force: true);
      }

      _ref.read(logProvider.notifier).info(
            isAutoRefresh
                ? '自动刷新：${tasks.length} 任务，${state.totalPendingCount} 待审'
                : '加载完成：${tasks.length} 任务，${state.totalPendingCount} 待审',
          );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
      _ref.read(logProvider.notifier).error('加载任务列表失败: $e');
    }
  }

  /// 加载任务详情（Job + 所有 Job 的待审 EP）
  /// 展开任务时调用，单任务刷新时调用
  Future<void> loadTaskDetail(int taskId, {bool force = false}) async {
    if (state.loadingTasks.contains(taskId)) return;
    if (!force &&
        state.jobsByTask.containsKey(taskId) &&
        !state.taskErrors.containsKey(taskId)) {
      return; // 已加载且无错误
    }

    state = state.copyWith(
      loadingTasks: {...state.loadingTasks, taskId},
      clearTaskError: true,
      clearTaskErrorId: taskId,
    );

    try {
      // 1. 拉取该任务的所有 Job
      final jobs = await _repo.fetchAllJobsForTask(taskId);
      if (!mounted) return;

      // 2. 收集所有需要扫描的 job ID（allJobIdsForScan = job.id + variables[].jobId）
      //    同时记录每个扫描 ID 对应的 primary job.id（用于合并结果）
      final specs = <_EpSpec>[];
      final primaryIdByJobId = <int, int>{};
      for (final j in jobs) {
        for (final jid in j.allJobIdsForScan) {
          specs.add(_EpSpec(taskId, jid, '${taskId}_$jid'));
          primaryIdByJobId[jid] = j.id;
        }
      }

      // 3. 并发拉取每个 Job 的待审 EP（用 taskDetailConcurrency 避免限流）
      final epsResults =
          await ConcurrencyUtils.runConcurrent<_EpSpec, List<Episode>>(
        specs,
        (spec, _) => _repo.fetchAllEpisodesForJob(
          taskId: spec.taskId,
          jobId: spec.jobId,
          onlyStatus9: true,
        ),
        AppConfig.taskDetailConcurrency,
      );

      if (!mounted) return;

      // 4. 合并结果：将所有扫描 ID 的 EP 归并到 primary job.id 下
      final newJobsMap = Map<int, List<Job>>.from(state.jobsByTask);
      newJobsMap[taskId] = jobs;

      final newEpsMap = Map<String, List<Episode>>.from(state.epsByJob);
      final newOpened = Set<String>.from(state.openedEpKeys);

      // 按 primary job.id 合并 EP，去重
      final mergedEps = <String, List<Episode>>{};
      final loadedSpecs = <_EpSpec>[];
      final loadedResults = <List<Episode>?>[];
      final epIdsSeen = <String>{}; // 用于跨扫描 ID 去重

      for (var i = 0; i < specs.length; i++) {
        final spec = specs[i];
        final eps = epsResults[i];
        final primaryId = primaryIdByJobId[spec.jobId] ?? spec.jobId;
        final mergeKey = '${spec.taskId}_$primaryId';

        final bucket = mergedEps.putIfAbsent(mergeKey, () => <Episode>[]);
        for (final ep in eps ?? const <Episode>[]) {
          final epIdKey = 'task${spec.taskId}-ep${ep.id}';
          if (epIdsSeen.add(epIdKey)) {
            bucket.add(ep);
          }
          if (_storage.isEpOpenedToday(epIdKey)) {
            newOpened.add(epIdKey);
          }
        }

        loadedSpecs.add(_EpSpec(taskId, primaryId, mergeKey));
        loadedResults.add(eps);
      }

      newEpsMap.addAll(mergedEps);

      final newLoading = Set<int>.from(state.loadingTasks)..remove(taskId);

      state = state.copyWith(
        jobsByTask: newJobsMap,
        epsByJob: newEpsMap,
        openedEpKeys: newOpened,
        loadingTasks: newLoading,
        clearTaskError: true,
        clearTaskErrorId: taskId,
      );

      final epTotal = loadedResults.fold<int>(0, (s, e) => s + (e?.length ?? 0));
      _ref.read(logProvider.notifier).info(
            '任务 #$taskId 加载完成：${jobs.length} Job，$epTotal 待审 EP',
          );

      // 5. 自动打开新 EP
      if (_autoOpen && !_isPaused) {
        await _autoOpenNewEps(loadedSpecs, loadedResults);
      }
    } catch (e) {
      if (!mounted) return;
      final newLoading = Set<int>.from(state.loadingTasks)..remove(taskId);
      state = state.copyWith(
        loadingTasks: newLoading,
        taskErrors: {...state.taskErrors, taskId: '$e'},
      );
      _ref.read(logProvider.notifier).error('任务 #$taskId 加载失败: $e');
    }
  }

  /// 单任务刷新（强制重新加载）
  Future<void> refreshTask(int taskId) async {
    // 清除该任务的缓存
    final newJobsMap = Map<int, List<Job>>.from(state.jobsByTask)..remove(taskId);
    final newEpsMap = Map<String, List<Episode>>.from(state.epsByJob);
    newEpsMap.removeWhere((k, _) => k.startsWith('${taskId}_'));
    state = state.copyWith(
      jobsByTask: newJobsMap,
      epsByJob: newEpsMap,
      clearTaskError: true,
      clearTaskErrorId: taskId,
    );
    await loadTaskDetail(taskId, force: true);
  }

  /// 自动打开新的普通 EP（间隔 400ms 逐个打开，避免弹窗拦截）
  Future<void> _autoOpenNewEps(
    List<_EpSpec> specs,
    List<List<Episode>?> results,
  ) async {
    final newEps = <_EpToOpen>[];
    for (var i = 0; i < specs.length; i++) {
      final eps = results[i];
      if (eps == null) continue;
      final spec = specs[i];
      for (final ep in eps) {
        final epKey = 'task${spec.taskId}-ep${ep.id}';
        if (!state.openedEpKeys.contains(epKey) && !ep.isFailed) {
          newEps.add(_EpToOpen(
            taskId: spec.taskId,
            jobId: spec.jobId,
            episodeId: ep.id,
            key: epKey,
          ));
        }
      }
    }
    if (newEps.isEmpty) return;
    _ref.read(logProvider.notifier).auto(
          '自动打开 ${newEps.length} 个新普通EP（失败EP不自动打开）',
        );

    // 先同步标记所有新 EP 为已打开（占位去重），再逐个延迟打开
    // 对齐原脚本第 945-951 行：markEpOpened 在 setTimeout 之前同步执行
    final newOpened = Set<String>.from(state.openedEpKeys);
    for (final ep in newEps) {
      await _storage.markEpOpened(ep.key);
      newOpened.add(ep.key);
    }
    state = state.copyWith(openedEpKeys: newOpened);

    for (var idx = 0; idx < newEps.length; idx++) {
      final ep = newEps[idx];
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final url = ApiClient.buildEpisodeCheckUrl(
        taskId: ep.taskId,
        jobId: ep.jobId,
        episodeId: ep.episodeId,
      );
      _ref.read(epOpenRequestProvider.notifier).request(url);
    }
  }

  /// 切换任务展开；展开时若未加载则触发加载
  /// [isExpanded] 为 true 表示展开，false 表示折叠
  Future<void> toggleExpand(int taskId, {required bool isExpanded}) async {
    if (isExpanded) {
      _expandedTaskIds.add(taskId);
      if (!state.jobsByTask.containsKey(taskId) ||
          state.taskErrors.containsKey(taskId)) {
        await loadTaskDetail(taskId);
      }
    } else {
      _expandedTaskIds.remove(taskId);
    }
  }

  /// 标记 EP 已打开
  Future<void> markEpOpened(String epKey) async {
    await _storage.markEpOpened(epKey);
    state = state.copyWith(openedEpKeys: {...state.openedEpKeys, epKey});
  }

  /// 获取首帧预览 URL（缓存 null 避免重复请求）
  Future<void> fetchPreviewUrl(int taskId, int jobId) async {
    final key = '${taskId}_$jobId';
    if (state.previewUrls.containsKey(key)) return;
    if (state.previewNullKeys.contains(key)) return;
    final url = await _repo.fetchPreviewUrl(taskId: taskId, jobId: jobId);
    if (!mounted) return;
    if (url != null) {
      state = state.copyWith(
        previewUrls: {...state.previewUrls, key: url},
      );
    } else {
      state = state.copyWith(
        previewNullKeys: {...state.previewNullKeys, key},
      );
    }
  }

  /// EP 审核成功后调用（WebView 监听"标注成功"消息时触发）
  Future<void> onEpisodeReviewed(int episodeId) async {
    final stats = _ref.read(statsProvider.notifier);
    final success = await stats.addSuccess();
    if (!success) return;
    final frames = await _repo.fetchEpisodeMaxFrames(episodeId);
    if (frames > 0) {
      await stats.addFrames(frames);
      _ref.read(logProvider.notifier).success(
            '标注成功！本条: ${FormatUtils.formatTimeShort(frames)} | '
            '今日总时长: ${FormatUtils.formatTimeShort(_ref.read(statsProvider).todayFrames)}',
          );
    } else {
      _ref.read(logProvider.notifier).success(
            '标注成功！今日已完成 ${_ref.read(statsProvider).todayCount} 条',
          );
    }
  }
}

class _EpSpec {
  const _EpSpec(this.taskId, this.jobId, this.key);
  final int taskId;
  final int jobId;
  final String key;
}

class _EpToOpen {
  const _EpToOpen({
    required this.taskId,
    required this.jobId,
    required this.episodeId,
    required this.key,
  });
  final int taskId;
  final int jobId;
  final int episodeId;
  final String key;
}

/// EP 打开请求 Notifier（单条队列，UI 层监听后 consume）
class EpOpenRequestNotifier extends StateNotifier<String?> {
  EpOpenRequestNotifier() : super(null);
  void request(String url) => state = url;
  void consume() => state = null;
}

final epOpenRequestProvider =
    StateNotifierProvider<EpOpenRequestNotifier, String?>((ref) {
  return EpOpenRequestNotifier();
});

/// 任务列表 provider
final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(ref);
});
