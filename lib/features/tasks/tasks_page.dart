import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/episode.dart';
import '../../data/models/task.dart';
import '../../providers/app_providers.dart';
import '../../providers/log_provider.dart';
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
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final selectedTask = _findTask(state.tasks, selectedTaskId);

    return Column(
      children: [
        _buildToolbar(state, selectedTask, settings.isPaused),
        _buildTableHeader(selectedTask),
        Expanded(
          child: _buildBody(state, settings, selectedTask),
        ),
        _buildFooter(state),
      ],
    );
  }

  Widget _buildToolbar(TasksState state, Task? selectedTask, bool isPaused) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.separatorLight),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: isPaused ? '继续抓取' : '开启抓取',
            color: AppTheme.textPrimary,
            onPressed: () async {
              await ref.read(refreshProvider.notifier).togglePause();
            },
          ),
          const SizedBox(width: 12),
          _TaskPicker(
            tasks: state.tasks,
            selectedTask: selectedTask,
            onChanged: (task) async {
              if (task == null) return;
              ref.read(selectedTaskIdProvider.notifier).state = task.id;
              await ref
                  .read(tasksProvider.notifier)
                  .toggleExpand(task.id, isExpanded: true);
            },
          ),
          const SizedBox(width: 12),
          _ToolbarIconButton(
            icon: Icons.delete_outline,
            label: '清空列表',
            color: AppTheme.danger,
            onPressed: state.isLoading
                ? null
                : () async {
                    ref.read(selectedTaskIdProvider.notifier).state = null;
                    await ref.read(tasksProvider.notifier).fetchTasks();
                  },
          ),
          const SizedBox(width: 12),
          _ToolbarIconButton(
            icon: Icons.download_outlined,
            label: '批量打开',
            color: AppTheme.success,
            onPressed: selectedTask == null
                ? null
                : () => ref.read(tasksProvider.notifier).openNormalEps(
                      selectedTask.id,
                    ),
          ),
          const Spacer(),
          _ToolbarSquareButton(
            icon: Icons.refresh,
            tooltip: '刷新任务列表',
            onPressed: state.isLoading
                ? null
                : () => ref.read(tasksProvider.notifier).fetchTasks(),
          ),
          const SizedBox(width: 6),
          _ToolbarSquareButton(
            icon: Icons.apps_rounded,
            tooltip: '资源视图',
            selected: true,
            onPressed: () => ref.read(selectedTaskIdProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(Task? selectedTask) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        border: Border(
          bottom: BorderSide(color: AppTheme.separatorLight),
        ),
      ),
      child: Row(
        children: [
          _BackHeaderButton(
            width: 88,
            onPressed: selectedTask == null
                ? null
                : () => ref.read(selectedTaskIdProvider.notifier).state = null,
          ),
          const _HeaderCell(width: 88, label: '状态'),
          const Expanded(child: _HeaderCell(label: '描述', icon: Icons.search)),
          const _HeaderCell(width: 120, label: '操作'),
        ],
      ),
    );
  }

  Task? _findTask(List<Task> tasks, int? taskId) {
    if (taskId == null) return null;
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  Widget _buildBody(
    TasksState state,
    AppSettings settings,
    Task? selectedTask,
  ) {
    if (settings.cookie.isEmpty) {
      return _buildCenteredState(
        icon: Icons.key_off_outlined,
        title: '未配置 Token',
        message: '前往系统设置填入浏览器 Cookie 后再获取资源',
        color: AppTheme.warning,
      );
    }

    if (state.error != null) {
      return _buildCenteredState(
        icon: Icons.wifi_off_outlined,
        title: state.error!.contains('登录失效') ? '登录失效' : '加载失败',
        message: state.error!,
        color: AppTheme.danger,
        actionLabel: '重试',
        onAction: () => ref.read(tasksProvider.notifier).fetchTasks(),
      );
    }

    if (state.isLoading && state.tasks.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (state.tasks.isEmpty) {
      return _buildCenteredState(
        icon: Icons.folder_off_outlined,
        title: '无数据',
        message: '当前没有待审核任务',
        color: AppTheme.textTertiary,
      );
    }

    if (selectedTask == null) {
      return _buildTaskOverview(state);
    }

    return _buildTaskRows(selectedTask, state, settings);
  }

  Widget _buildTaskOverview(TasksState state) {
    final sorted = [...state.tasks]
      ..sort((a, b) => b.notCheckCount.compareTo(a.notCheckCount));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: 20,
        endIndent: 20,
        color: AppTheme.separatorLight,
      ),
      itemBuilder: (context, index) {
        final task = sorted[index];
        return _ResourceRow(
          domain: '#${task.id}',
          status: task.notCheckCount > 0 ? '待审核' : '完成',
          description: task.name,
          statusColor: task.notCheckCount > 0 ? AppTheme.success : AppTheme.textTertiary,
          onTap: () async {
            ref.read(selectedTaskIdProvider.notifier).state = task.id;
            await ref
                .read(tasksProvider.notifier)
                .toggleExpand(task.id, isExpanded: true);
          },
          action: _RowAction(
            icon: Icons.chevron_right,
            tooltip: '打开任务',
            onPressed: () async {
              ref.read(selectedTaskIdProvider.notifier).state = task.id;
              await ref
                  .read(tasksProvider.notifier)
                  .toggleExpand(task.id, isExpanded: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskRows(Task task, TasksState state, AppSettings settings) {
    final isLoading = state.loadingTasks.contains(task.id);
    final error = state.taskErrors[task.id];
    final jobs = state.jobsByTask[task.id];

    if (error != null) {
      return _buildCenteredState(
        icon: Icons.error_outline,
        title: '任务加载失败',
        message: error,
        color: AppTheme.danger,
        actionLabel: '重试',
        onAction: () => ref.read(tasksProvider.notifier).refreshTask(task.id),
      );
    }

    if ((jobs == null || jobs.isEmpty) && isLoading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (jobs == null || jobs.isEmpty) {
      return _buildCenteredState(
        icon: Icons.inbox_outlined,
        title: '无数据',
        message: '该任务暂无 Job 或 EP',
        color: AppTheme.textTertiary,
        actionLabel: '刷新',
        onAction: () => ref.read(tasksProvider.notifier).refreshTask(task.id),
      );
    }

    final rows = <_EpRow>[];
    for (final job in jobs) {
      final jobIds = job.displayJobIds;
      final hasEpisodes = jobIds.any(
        (jobId) => (state.epsByJob['${task.id}_$jobId']?.isNotEmpty ?? false),
      );
      if (!settings.showAllJobs && !hasEpisodes) continue;
      for (final jobId in jobIds) {
        final eps = state.epsByJob['${task.id}_$jobId'];
        if (eps == null || eps.isEmpty) {
          rows.add(_EpRow.empty(task, jobId));
        } else {
          for (final ep in eps) {
            rows.add(_EpRow(task: task, jobId: jobId, episode: ep));
          }
        }
      }
    }

    if (rows.isEmpty) {
      return _buildCenteredState(
        icon: Icons.image_not_supported_outlined,
        title: '无数据',
        message: '没有可展示的 EP 资源',
        color: AppTheme.textTertiary,
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: AppTheme.separatorLight,
          ),
          itemBuilder: (context, index) => _buildEpRow(rows[index], state),
        ),
        // 移除右上角的loading
      ],
    );
  }

  Widget _buildEpRow(_EpRow row, TasksState state) {
    final ep = row.episode;
    if (ep == null) {
      return _ResourceRow(
        domain: '#${row.task.id}',
        status: '无 EP',
        description: 'Job ${row.jobId}',
        statusColor: AppTheme.textTertiary,
        onTap: () => ref.read(tasksProvider.notifier).refreshTask(row.task.id),
        action: _RowAction(
          icon: Icons.refresh,
          tooltip: '刷新任务',
          onPressed: () => ref.read(tasksProvider.notifier).refreshTask(row.task.id),
        ),
      );
    }

    final epKey = 'task${row.task.id}-ep${ep.id}';
    final isOpened = state.openedEpKeys.contains(epKey);
    final isFailed = ep.isFailed;
    final status = isFailed ? '失败' : (isOpened ? '已打开' : '待审核');
    final statusColor = isFailed
        ? AppTheme.danger
        : isOpened
            ? AppTheme.textTertiary
            : AppTheme.success;

    return _ResourceRow(
      domain: '#${row.task.id}',
      status: status,
      description: '${row.task.name} · Job ${row.jobId} · EP ${ep.id}',
      statusColor: statusColor,
      onTap: () => _onEpTap(row.task.id, row.jobId, ep.id, epKey),
      action: _RowAction(
        icon: Icons.open_in_new,
        tooltip: '打开 EP',
        onPressed: () => _onEpTap(row.task.id, row.jobId, ep.id, epKey),
      ),
    );
  }

  Widget _buildCenteredState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: color.withValues(alpha: 0.55)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(TasksState state) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.separatorLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FooterLink('证书下载', () => _openUrl('https://github.com/Hongwei-name/Genie-Studio-App/releases')),
          _FooterLink('软件源码', () => _openUrl('https://github.com/Hongwei-name/Genie-Studio-App')),
          _FooterLink('帮助支持', () => _openUrl('https://github.com/Hongwei-name/Genie-Studio-App/issues')),
          _FooterLink('更新日志', () => _openUrl('https://github.com/Hongwei-name/Genie-Studio-App/releases')),
          const Spacer(),
          Text(
            state.lastUpdated == null
                ? '${state.tasks.length} 个任务'
                : '${state.tasks.length} 个任务 · ${state.totalPendingCount} 待审',
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ref.read(logProvider.notifier).warn('无法打开链接：$value');
      }
    }
  }

  void _onEpTap(int taskId, int jobId, int epId, String epKey) async {
    final url = ApiClient.buildEpisodeCheckUrl(
      taskId: taskId,
      jobId: jobId,
      episodeId: epId,
    );
    await ref.read(tasksProvider.notifier).markEpOpened(epKey);
    ref.read(epOpenRequestProvider.notifier).request(url);
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.tasks,
    required this.selectedTask,
    required this.onChanged,
  });

  final List<Task> tasks;
  final Task? selectedTask;
  final ValueChanged<Task?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 310,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separatorLight),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Task>(
          value: selectedTask,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          hint: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              '图片',
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          selectedItemBuilder: (context) {
            return tasks.map((task) {
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${task.name}  ×',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            }).toList();
          },
          items: tasks.map((task) {
            return DropdownMenuItem<Task>(
              value: task,
              child: Text(
                '#${task.id} · ${task.name} · ${task.notCheckCount} EP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: tasks.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 13, color: color)),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF7F7F8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15, color: onPressed == null ? AppTheme.textTertiary : color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: onPressed == null ? AppTheme.textTertiary : color,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
      ),
    );
  }
}

class _ToolbarSquareButton extends StatelessWidget {
  const _ToolbarSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          color: selected ? AppTheme.primary : AppTheme.textSecondary,
          style: IconButton.styleFrom(
            backgroundColor: selected ? AppTheme.primary.withValues(alpha: 0.08) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackHeaderButton extends StatelessWidget {
  const _BackHeaderButton({required this.width, required this.onPressed});

  final double width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: '返回任务列表',
          child: IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_back_rounded),
            iconSize: 18,
            color: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                side: const BorderSide(color: AppTheme.separatorLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.width, this.icon});

  final String label;
  final double? width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: AppTheme.textTertiary),
        ],
      ],
    );

    if (width == null) return content;
    return SizedBox(width: width, child: content);
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.domain,
    required this.status,
    required this.description,
    required this.statusColor,
    required this.action,
    this.onTap,
  });

  final String domain;
  final String status;
  final String description;
  final Color statusColor;
  final _RowAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            SizedBox(width: 88, child: _DomainCell(domain)),
            SizedBox(
              width: 88,
              child: _StatusPill(label: status, color: statusColor),
            ),
            Expanded(child: _DescriptionCell(description)),
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SmallRowButton(action: action),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainCell extends StatelessWidget {
  const _DomainCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionCell extends StatelessWidget {
  const _DescriptionCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _SmallRowButton extends StatelessWidget {
  const _SmallRowButton({required this.action});

  final _RowAction action;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: 18),
          padding: EdgeInsets.zero,
          color: AppTheme.textSecondary,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceHover,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTheme.primary),
      ),
    );
  }
}

class _RowAction {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

class _EpRow {
  const _EpRow({
    required this.task,
    required this.jobId,
    required this.episode,
  });

  const _EpRow.empty(this.task, this.jobId) : episode = null;

  final Task task;
  final int jobId;
  final Episode? episode;
}
