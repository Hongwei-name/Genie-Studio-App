import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/concurrency_utils.dart';
import '../models/episode.dart';
import '../models/job.dart';
import '../models/resource.dart';
import '../models/task.dart';

/// 扫描进度回调
typedef ScanProgressCallback = void Function(int percent, String text);

/// 扫描结果
class ScanResult {
  const ScanResult({
    required this.failedEpisodes,
    required this.taskCount,
    required this.jobCount,
    required this.selfReviewExcluded,
    required this.totalEps,
    required this.failedEpsCount,
    required this.filteredCount,
  });

  final List<FailedEpisode> failedEpisodes;
  final int taskCount;
  final int jobCount;
  final int selfReviewExcluded;
  final int totalEps;
  final int failedEpsCount;
  final int filteredCount;
}

/// 审核 Repository
/// 封装所有 API 调用 + 并发逻辑
/// 对齐原脚本 API 对象的所有方法
class ReviewRepository {
  ReviewRepository();

  final _api = ApiClient.instance;

  /// 获取所有任务（并发分页）
  /// 对齐原脚本 fetchAllTasks
  Future<List<Task>> fetchAllTasks({
    required int concurrency,
  }) async {
    // 先获取第1页
    final firstRes = await _api.fetchTasks(pageNum: 1);
    if (firstRes.isUnauthorized) {
      throw const ApiException('登录失效', type: ApiErrorType.unauthorized);
    }
    if (!firstRes.isSuccess || firstRes.data == null) return [];

    final firstTasks = parseList(firstRes.data, Task.fromJson);
    if (firstTasks.length < AppConfig.taskPageSize) {
      return firstTasks;
    }

    // 第1页满，并发获取剩余页
    final remainingPages = List.generate(
      AppConfig.maxTaskPageEstimate - 1,
      (i) => i + 2,
    );

    final results = await ConcurrencyUtils.runConcurrent<int, List<Task>>(
      remainingPages,
      (pageNum, _) async {
        final res = await _api.fetchTasks(pageNum: pageNum);
        if (!res.isSuccess || res.data == null) return <Task>[];
        return parseList(res.data, Task.fromJson);
      },
      concurrency,
    );

    final allTasks = List<Task>.from(firstTasks);
    for (final pageTasks in results) {
      if (pageTasks == null) continue;  // 网络抖动跳过，不中断
      allTasks.addAll(pageTasks);
      if (pageTasks.length < AppConfig.taskPageSize) break;
    }
    return allTasks;
  }

  /// 获取任务的所有 Job（分页）
  /// 对齐原脚本 fetchAllJobsForTask
  Future<List<Job>> fetchAllJobsForTask(int taskId) async {
    final allJobs = <Job>[];
    int pageNum = 1;
    while (true) {
      final res = await _api.fetchJobs(taskId: taskId, pageNum: pageNum);
      if (res.isUnauthorized) return allJobs;
      if (!res.isSuccess || res.data == null) return allJobs;
      final jobs = parseList(res.data, Job.fromJson);
      allJobs.addAll(jobs);
      if (jobs.length < AppConfig.jobPageSize) break;
      pageNum++;
    }
    return allJobs;
  }

  /// 获取 Job 的待审 EP（分页）
  /// 对齐原脚本 fetchEps（只取第 1 页）/ fetchAllEpsForJob（全量分页）
  /// [maxPages] 限制最大页数，默认 3 页（30 条）避免请求过多被限流
  /// 失败扫描时传 maxPages=0 表示不限（全量）
  Future<List<Episode>> fetchAllEpisodesForJob({
    required int taskId,
    required int jobId,
    bool onlyStatus9 = true,
    int maxPages = 3,
  }) async {
    final allEps = <Episode>[];
    int pageNum = 1;
    while (true) {
      final res = await _api.fetchEpisodes(
        taskId: taskId,
        jobId: jobId,
        pageNum: pageNum,
        onlyStatus9: onlyStatus9,
      );
      if (res.isUnauthorized) return allEps;
      if (!res.isSuccess || res.data == null) return allEps;
      final eps = parseList(res.data, Episode.fromJson);
      allEps.addAll(eps);
      if (eps.length < AppConfig.epPageSize) break;
      pageNum++;
      if (maxPages > 0 && pageNum > maxPages) break;
    }
    return allEps;
  }

  /// 扫描所有验收失败 EP（核心并发逻辑）
  /// 对齐原脚本 fetchFailedEpsFromAllTasks
  Future<ScanResult> scanFailedEpisodes({
    required int concurrency,
    required String screener,
    ScanProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, '获取任务列表...');

    // 1. 获取所有任务
    final allTasks = await fetchAllTasks(concurrency: concurrency);
    final taskIds = allTasks.map((t) => t.id).toList();
    onProgress?.call(10, '获取 Job (${taskIds.length} 任务)...');

    // 2. 并发获取所有任务的 Job
    final jobsResults = await ConcurrencyUtils.runConcurrent<int, List<Job>>(
      taskIds,
      (taskId, _) => fetchAllJobsForTask(taskId),
      concurrency,
    );

    // 预筛选：跳过无拒审 EP 的 Job
    final allJobSpecs = <_JobSpec>[];
    final seenJobIds = <int>{};
    for (var i = 0; i < jobsResults.length; i++) {
      final jobs = jobsResults[i];
      if (jobs == null) continue;
      final taskId = taskIds[i];
      for (final j in jobs) {
        if (j.unapprovedCount <= 0) continue;
        for (final jid in j.allJobIdsForScan) {
          if (jid > 0 && !seenJobIds.contains(jid)) {
            allJobSpecs.add(_JobSpec(taskId, jid));
            seenJobIds.add(jid);
          }
        }
      }
    }
    onProgress?.call(20, '获取 EP (0/${allJobSpecs.length} Job)...');

    // 3. 并发获取所有 Job 的 EP
    var epCompleted = 0;
    final epResults = await ConcurrencyUtils.runConcurrent<_JobSpec, List<Episode>>(
      allJobSpecs,
      (spec, _) async {
        final eps = await fetchAllEpisodesForJob(
          taskId: spec.taskId,
          jobId: spec.jobId,
          onlyStatus9: false,  // 失败扫描不加 status=9 过滤
          maxPages: 0,         // 全量分页
        );
        epCompleted++;
        final pct = 20 + ((epCompleted / allJobSpecs.length) * 75).toInt();
        onProgress?.call(pct, '获取 EP ($epCompleted/${allJobSpecs.length} Job)...');
        return eps;
      },
      concurrency,
    );

    // 4. 过滤失败 EP
    var totalEps = 0;
    var failedEpsCount = 0;
    var filteredCount = 0;
    var selfReviewExcluded = 0;
    final failedEpisodes = <FailedEpisode>[];

    for (var i = 0; i < epResults.length; i++) {
      final eps = epResults[i];
      if (eps == null) continue;
      final spec = allJobSpecs[i];
      for (final ep in eps) {
        totalEps++;
        if (ep.isSelfReview()) selfReviewExcluded++;
        if (ep.isFailed) {
          failedEpsCount++;
          if (ep.isByScreener(screener)) {
            filteredCount++;
            failedEpisodes.add(FailedEpisode(
              id: ep.id,
              taskId: spec.taskId,
              jobId: spec.jobId,
              url: ApiClient.buildEpisodeCheckUrl(
                taskId: spec.taskId,
                jobId: spec.jobId,
                episodeId: ep.id,
              ),
              key: 'task${spec.taskId}-ep${ep.id}',
              reason: ep.failReason,
            ));
          }
        }
      }
    }

    onProgress?.call(100, '完成');
    return ScanResult(
      failedEpisodes: failedEpisodes,
      taskCount: taskIds.length,
      jobCount: allJobSpecs.length,
      selfReviewExcluded: selfReviewExcluded,
      totalEps: totalEps,
      failedEpsCount: failedEpsCount,
      filteredCount: filteredCount,
    );
  }

  /// 获取 EP 的 max frames（视频时长）
  /// 对齐原脚本 fetchMaxFrames
  Future<int> fetchEpisodeMaxFrames(int episodeId) async {
    try {
      final res = await _api.fetchEpisodeReviewData(episodeId);
      if (res.isSuccess && res.data is Map<String, dynamic>) {
        final max = (res.data as Map<String, dynamic>)['max'];
        return (max as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// 获取任务资源列表
  /// 对齐原脚本 fetchResources
  Future<List<String>> fetchResources(int taskId) async {
    try {
      final res = await _api.fetchResources(taskId);
      if (res.isSuccess) {
        final list = parseList(res.data, Resource.fromJson);
        return list.map((r) => r.name).where((n) => n.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 获取首帧预览 URL
  /// 对齐原脚本 fetchPreviewUrl
  Future<String?> fetchPreviewUrl({required int taskId, required int jobId}) async {
    try {
      final res = await _api.fetchJobAssignmentStat(jobId);
      if (res.isSuccess) {
        final assignments = parseList(res.data, Assignment.fromJson);
        if (assignments.isNotEmpty) {
          final first = assignments.first;
          if (first.assignmentId > 0 && first.displayName.isNotEmpty) {
            return ApiClient.buildPreviewUrl(
              taskId: taskId,
              jobId: jobId,
              assignmentId: first.assignmentId,
              collectorName: first.displayName,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class _JobSpec {
  const _JobSpec(this.taskId, this.jobId);
  final int taskId;
  final int jobId;
}
