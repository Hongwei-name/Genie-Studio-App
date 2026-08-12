import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/episode.dart';
import '../../data/models/task.dart';
import '../../providers/app_providers.dart';
import '../../providers/log_provider.dart';
import '../../providers/tasks_provider.dart';

/// 待审核 EP 页 - 仅显示 EP 网格
/// 任务列表已折叠进侧边栏二级菜单
/// 选中的任务通过 selectedTaskIdProvider 通信
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksProvider);
    final settings = ref.watch(settingsProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    if (settings.cookie.isEmpty) return _buildNoCookie();
    if (state.error != null) return _buildError(state.error!);
    if (state.tasks.isEmpty && !state.isLoading) return _buildEmpty();

    if (selectedTaskId == null) return _buildSelectPrompt(state);

    return _buildEpGrid(selectedTaskId, state, settings.epOpenMode);
  }

  // ═══════════════ EP 网格 ═══════════════

  Widget _buildEpGrid(int taskId, TasksState state, EpOpenMode openMode) {
    final task = state.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return _buildSelectPrompt(state);

    final jobs = state.jobsByTask[taskId];
    final isLoading = state.loadingTasks.contains(taskId);
    final error = state.taskErrors[taskId];

    if (error != null) return _buildTaskError(taskId, error);
    if (jobs == null && isLoading) return _buildLoadingDetail();
    if (jobs == null || jobs.isEmpty) return _buildNoJobs();

    final jobSpecs = <_JobSpec>[];
    for (final j in jobs) {
      for (final jid in j.displayJobIds) {
        jobSpecs.add(_JobSpec(taskId, jid));
      }
    }

    return Column(
      children: [
        _buildTaskHeader(task, jobSpecs.length, state),
        Container(height: 1, color: AppTheme.separator),
        Expanded(
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  itemCount: jobSpecs.length,
                  itemBuilder: (context, index) {
                    return _buildJobSection(jobSpecs[index], state);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTaskHeader(Task task, int jobCount, TasksState state) {
    var epTotal = 0;
    for (final j in state.jobsByTask[task.id] ?? []) {
      for (final jid in j.displayJobIds) {
        epTotal += (state.epsByJob['${task.id}_$jid'] ?? []).length;
      }
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '#${task.id} · $jobCount Job · $epTotal EP · 待审 ${task.notCheckCount}',
                  style: const TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: state.loadingTasks.contains(task.id)
                  ? null
                  : () => ref.read(tasksProvider.notifier).refreshTask(task.id),
              icon: const Icon(Icons.refresh, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: '刷新此任务',
              splashRadius: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSection(_JobSpec spec, TasksState state) {
    final key = '${spec.taskId}_${spec.jobId}';
    final eps = state.epsByJob[key];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline,
                  size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: AppTheme.spacingXs),
              Text(
                'Job ${spec.jobId}',
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (eps != null && eps.isNotEmpty) ...[
                const SizedBox(width: AppTheme.spacingXs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Text(
                    '${eps.length}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _buildPreviewButton(spec, state),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          if (eps == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              child: Text(
                '未加载',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.textTertiary,
                ),
              ),
            )
          else if (eps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              child: Text(
                '无待审 EP',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeCaption,
                  color: AppTheme.textTertiary,
                ),
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: eps.map((ep) => _buildEpCard(spec, ep, state)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewButton(_JobSpec spec, TasksState state) {
    final previewKey = '${spec.taskId}_${spec.jobId}';
    final url = state.previewUrls[previewKey];
    final hasPreview = url != null;

    return SizedBox(
      height: 24,
      child: TextButton.icon(
        onPressed: () => _openPreview(spec.taskId, spec.jobId, state),
        icon: Icon(
          Icons.play_arrow,
          size: 12,
          color: hasPreview ? AppTheme.success : AppTheme.textTertiary,
        ),
        label: Text(
          hasPreview ? '首帧' : '预览',
          style: TextStyle(
            fontSize: AppTheme.fontSizeCaption,
            color: hasPreview ? AppTheme.success : AppTheme.textTertiary,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 24),
        ),
      ),
    );
  }

  Widget _buildEpCard(_JobSpec spec, Episode ep, TasksState state) {
    final epKey = 'task${spec.taskId}-ep${ep.id}';
    final isFailed = ep.isFailed;
    final isOpened = state.openedEpKeys.contains(epKey);

    Color cardColor;
    Color textColor;
    Color borderColor;
    if (isFailed) {
      cardColor = AppTheme.danger.withValues(alpha: 0.08);
      textColor = AppTheme.danger;
      borderColor = AppTheme.danger.withValues(alpha: 0.3);
    } else if (isOpened) {
      cardColor = AppTheme.textTertiary.withValues(alpha: 0.08);
      textColor = AppTheme.textTertiary;
      borderColor = AppTheme.separator;
    } else {
      cardColor = AppTheme.primary.withValues(alpha: 0.06);
      textColor = AppTheme.primary;
      borderColor = AppTheme.primary.withValues(alpha: 0.25);
    }

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => _onEpTap(spec.taskId, spec.jobId, ep.id, epKey),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EP ${ep.id}',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (isFailed) ...[
                const SizedBox(width: AppTheme.spacingXs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: const Text(
                    '失败',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (isOpened) ...[
                const SizedBox(width: AppTheme.spacingXs),
                Icon(Icons.check, size: 12, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ 空状态 / 加载 / 错误 ═══════════════

  Widget _buildSelectPrompt(TasksState state) {
    final totalEps = state.epsByJob.values.fold(0, (sum, eps) => sum + eps.length);
    final openedCount = state.openedEpKeys.length;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: AppTheme.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            '从左侧选择任务',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            '${state.tasks.length} 任务 · $totalEps EP 已加载 · 今日打开 $openedCount',
            style: const TextStyle(
              fontSize: AppTheme.fontSizeCaption,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDetail() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: AppTheme.spacingMd),
          Text(
            '加载 Job 和 EP...',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoJobs() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined,
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            '该任务无 Job',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskError(int taskId, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              '加载失败',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              error,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(tasksProvider.notifier).refreshTask(taskId),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCookie() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.key_off, size: 48, color: AppTheme.warning),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              '未配置 Token',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            const Text(
              '前往"配置"页面填入从浏览器复制的 Cookie 字符串',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 48, color: AppTheme.success),
          const SizedBox(height: AppTheme.spacingMd),
          const Text(
            '暂无待审核任务',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppTheme.danger),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              error.contains('登录失效') ? '登录失效，请检查 Cookie' : '加载失败',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeBody,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton(
              onPressed: () => ref.read(tasksProvider.notifier).fetchTasks(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ 事件处理 ═══════════════

  void _onEpTap(int taskId, int jobId, int epId, String epKey) async {
    final url = ApiClient.buildEpisodeCheckUrl(
      taskId: taskId,
      jobId: jobId,
      episodeId: epId,
    );
    await ref.read(tasksProvider.notifier).markEpOpened(epKey);
    ref.read(epOpenRequestProvider.notifier).request(url);
  }

  void _openPreview(int taskId, int jobId, TasksState state) async {
    final previewKey = '${taskId}_$jobId';
    final url = state.previewUrls[previewKey];
    if (url != null) {
      ref.read(epOpenRequestProvider.notifier).request(url);
      return;
    }
    await ref.read(tasksProvider.notifier).fetchPreviewUrl(taskId, jobId);
    if (!mounted) return;
    final newUrl = ref.read(tasksProvider).previewUrls[previewKey];
    if (newUrl != null) {
      ref.read(epOpenRequestProvider.notifier).request(newUrl);
    } else {
      ref.read(logProvider.notifier).warn('获取预览链接失败');
    }
  }
}

class _JobSpec {
  const _JobSpec(this.taskId, this.jobId);
  final int taskId;
  final int jobId;
}
