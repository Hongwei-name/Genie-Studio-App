import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/episode.dart';
import '../../data/models/job.dart';
import '../../data/models/task.dart';
import '../../providers/app_providers.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/tasks_provider.dart';

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
    final selectedId = ref.watch(selectedTaskIdProvider);
    final selected = _taskFor(state.tasks, selectedId);

    return Column(
      children: [
        _WorkspaceHeader(state: state, settings: settings),
        _MetricStrip(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 278,
                  child: _TaskQueue(state: state, selected: selected),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _DetailPane(
                    state: state,
                    settings: settings,
                    selected: selected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Task? _taskFor(List<Task> tasks, int? id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
}

class _WorkspaceHeader extends ConsumerWidget {
  const _WorkspaceHeader({required this.state, required this.settings});

  final TasksState state;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = settings.isPaused;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '审核工作台',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '集中处理待审核资源，进度会在本地持续同步。',
                  style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          _HeaderAction(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? '继续同步' : '暂停同步',
            onTap: () => ref.read(refreshProvider.notifier).togglePause(),
            highlighted: paused,
          ),
          const SizedBox(width: 8),
          _HeaderAction(
            icon: Icons.refresh_rounded,
            label: '刷新',
            onTap: state.isLoading
                ? null
                : () => ref.read(tasksProvider.notifier).fetchTasks(),
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.state});

  final TasksState state;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        '任务',
        '${state.tasks.length}',
        Icons.grid_view_rounded,
        const Color(0xFF5E6AD2),
      ),
      (
        '待审核 EP',
        '${state.totalPendingCount}',
        Icons.pending_actions_rounded,
        const Color(0xFFE89A23),
      ),
      (
        '已展开',
        '${state.jobsByTask.length}',
        Icons.layers_outlined,
        const Color(0xFF238A68),
      ),
      (
        '最近同步',
        state.lastUpdated == null ? '--' : _time(state.lastUpdated!),
        Icons.sync_rounded,
        const Color(0xFF788492),
      ),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final value = values[index];
          return SizedBox(
            width: 166,
            child: _Metric(
              label: value.$1,
              value: value.$2,
              icon: value.$3,
              color: value.$4,
            ),
          );
        },
      ),
    );
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E9EE)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskQueue extends ConsumerWidget {
  const _TaskQueue({required this.state, required this.selected});

  final TasksState state;
  final Task? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 15, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '审核队列',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${state.tasks.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E8EE)),
          Expanded(
            child: state.tasks.isEmpty
                ? const Center(
                    child: Text(
                      '暂无任务',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: state.tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
                      final active = selected?.id == task.id;
                      return _TaskTile(
                        task: task,
                        selected: active,
                        loading: state.loadingTasks.contains(task.id),
                        onTap: () async {
                          ref.read(selectedTaskIdProvider.notifier).state =
                              task.id;
                          await ref
                              .read(tasksProvider.notifier)
                              .toggleExpand(task.id, isExpanded: true);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final Task task;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF4DF) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFD78A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFC65A)
                        : const Color(0xFFE3E7EC),
                  ),
                ),
                child: Text(
                  '${task.id}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFF875100)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.notCheckCount == 0
                          ? '已完成'
                          : '${task.notCheckCount} 个待审核',
                      style: TextStyle(
                        fontSize: 10,
                        color: task.notCheckCount == 0
                            ? AppTheme.success
                            : const Color(0xFFB46C00),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.7),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: selected
                      ? const Color(0xFFB87916)
                      : AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPane extends ConsumerWidget {
  const _DetailPane({
    required this.state,
    required this.settings,
    required this.selected,
  });

  final TasksState state;
  final AppSettings settings;
  final Task? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (settings.cookie.isEmpty)
      return _EmptyDetail(
        icon: Icons.key_off_outlined,
        title: '先连接审核账号',
        message: '在偏好设置中填入 Cookie 后，任务会自动出现在这里。',
      );
    if (state.error != null)
      return _EmptyDetail(
        icon: Icons.wifi_off_outlined,
        title: '同步失败',
        message: state.error!,
        action: '重试',
        onAction: () => ref.read(tasksProvider.notifier).fetchTasks(),
      );
    if (state.isLoading && state.tasks.isEmpty)
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (selected == null) return _WelcomeDetail(state: state);

    final jobs = state.jobsByTask[selected!.id];
    if (state.taskErrors[selected!.id] != null)
      return _EmptyDetail(
        icon: Icons.error_outline,
        title: '任务加载失败',
        message: state.taskErrors[selected!.id]!,
        action: '重新加载',
        onAction: () =>
            ref.read(tasksProvider.notifier).refreshTask(selected!.id),
      );
    if (jobs == null || jobs.isEmpty) {
      if (state.loadingTasks.contains(selected!.id))
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return _EmptyDetail(
        icon: Icons.inbox_outlined,
        title: '等待资源',
        message: '这个任务还没有加载 Job 与 EP。',
        action: '加载详情',
        onAction: () => ref
            .read(tasksProvider.notifier)
            .loadTaskDetail(selected!.id, force: true),
      );
    }

    final rows = _rows(selected!, jobs, state, settings);
    return _DetailContent(task: selected!, rows: rows, state: state);
  }

  List<_EpRow> _rows(
    Task task,
    List<Job> jobs,
    TasksState state,
    AppSettings settings,
  ) {
    final rows = <_EpRow>[];
    for (final job in jobs) {
      for (final jobId in job.displayJobIds) {
        final eps = state.epsByJob['${task.id}_$jobId'] ?? const <Episode>[];
        if (!settings.showAllJobs && eps.isEmpty) continue;
        if (eps.isEmpty) rows.add(_EpRow(task: task, jobId: jobId));
        for (final ep in eps)
          rows.add(_EpRow(task: task, jobId: jobId, episode: ep));
      }
    }
    return rows;
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.task,
    required this.rows,
    required this.state,
  });

  final Task task;
  final List<_EpRow> rows;
  final TasksState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 14, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '任务 #${task.id}  ·  ${rows.where((r) => r.episode != null).length} 个 EP',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(tasksProvider.notifier).openNormalEps(task.id),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('批量打开'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF26765E),
                    side: const BorderSide(color: Color(0xFF9FD5C2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7EAF0)),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      '没有可展示的 EP',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) =>
                        _EpisodeTile(row: rows[index], state: state),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.row, required this.state});

  final _EpRow row;
  final TasksState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ep = row.episode;
    if (ep == null) {
      return _RowSurface(
        icon: Icons.layers_outlined,
        color: AppTheme.textTertiary,
        title: 'Job ${row.jobId}',
        subtitle: '暂无待审核 EP',
        trailing: IconButton(
          onPressed: () =>
              ref.read(tasksProvider.notifier).refreshTask(row.task.id),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          tooltip: '刷新任务',
        ),
      );
    }
    final key = 'task${row.task.id}-ep${ep.id}';
    final opened = state.openedEpKeys.contains(key);
    final failed = ep.isFailed;
    final color = failed
        ? AppTheme.danger
        : opened
        ? AppTheme.textTertiary
        : AppTheme.success;
    return _RowSurface(
      icon: failed
          ? Icons.report_gmailerrorred_outlined
          : opened
          ? Icons.check_circle_outline
          : Icons.play_circle_outline,
      color: color,
      title: 'EP ${ep.id}',
      subtitle:
          'Job ${row.jobId}  ·  ${failed
              ? ep.failReason
              : opened
              ? '已打开，等待下一步处理'
              : '待审核资源'}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _preview(ref, row, state),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            tooltip: '预览',
          ),
          IconButton(
            onPressed: () => _open(ref, row, key),
            icon: const Icon(Icons.arrow_outward_rounded, size: 18),
            tooltip: '打开 EP',
          ),
        ],
      ),
    );
  }

  Future<void> _open(WidgetRef ref, _EpRow row, String key) async {
    final url = ApiClient.buildEpisodeCheckUrl(
      taskId: row.task.id,
      jobId: row.jobId,
      episodeId: row.episode!.id,
    );
    await ref.read(tasksProvider.notifier).markEpOpened(key);
    ref.read(epOpenRequestProvider.notifier).request(url);
  }

  Future<void> _preview(WidgetRef ref, _EpRow row, TasksState state) async {
    final previewKey = '${row.task.id}_${row.jobId}';
    final url = state.previewUrls[previewKey];
    if (url != null) {
      ref.read(epOpenRequestProvider.notifier).request(url);
      return;
    }
    await ref
        .read(tasksProvider.notifier)
        .fetchPreviewUrl(row.task.id, row.jobId);
    final newUrl = ref.read(tasksProvider).previewUrls[previewKey];
    if (newUrl != null)
      ref.read(epOpenRequestProvider.notifier).request(newUrl);
  }
}

class _RowSurface extends StatelessWidget {
  const _RowSurface({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _WelcomeDetail extends StatelessWidget {
  const _WelcomeDetail({required this.state});
  final TasksState state;

  @override
  Widget build(BuildContext context) => _EmptyDetail(
    icon: Icons.space_dashboard_outlined,
    title: '选择一个任务开始',
    message:
        '从左侧队列选中任务，查看 Job、EP 并开始审核。\n当前共有 ${state.totalPendingCount} 个 EP 等待处理。',
  );
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFB87916), size: 25),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
              if (action != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: highlighted
            ? const Color(0xFFB46C00)
            : AppTheme.textSecondary,
        backgroundColor: highlighted ? const Color(0xFFFFF5E2) : null,
        side: BorderSide(
          color: highlighted
              ? const Color(0xFFFFD58C)
              : const Color(0xFFDDE2E9),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      ),
    );
  }
}

class _EpRow {
  const _EpRow({required this.task, required this.jobId, this.episode});
  final Task task;
  final int jobId;
  final Episode? episode;
}
