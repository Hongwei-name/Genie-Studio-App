import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/daily_quote_provider.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/tasks_provider.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final tasks = ref.watch(tasksProvider);
    final failed = ref.watch(failEpsProvider);
    final logs = ref.watch(logProvider);
    final dailyQuote = ref.watch(dailyQuoteProvider);
    final total =
        stats.todayCount + tasks.totalPendingCount + failed.failedEps.length;
    final completion = total == 0
        ? 0.0
        : (stats.todayCount / total).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(stats: stats, onReset: () => _reset(context, ref)),
          const SizedBox(height: 20),
          _KpiRow(
            stats: stats,
            tasks: tasks,
            failedCount: failed.failedEps.length,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final quotePanel = _DailyQuotePanel(
                state: dailyQuote,
                onRefresh: () =>
                    ref.read(dailyQuoteProvider.notifier).refresh(),
              );
              final completionPanel = _CompletionPanel(
                completion: completion,
                stats: stats,
                pending: tasks.totalPendingCount,
                failed: failed.failedEps.length,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: quotePanel),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: completionPanel),
                  ],
                );
              }
              return Column(
                children: [
                  quotePanel,
                  const SizedBox(height: 14),
                  completionPanel,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final load = _TaskLoadPanel(tasks: tasks);
              final events = _EventsPanel(entries: logs.entries);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: load),
                    const SizedBox(width: 14),
                    Expanded(child: events),
                  ],
                );
              }
              return Column(
                children: [load, const SizedBox(height: 14), events],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置今日统计'),
        content: const Text('完成数量和视频时长会被清零，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(statsProvider.notifier).reset();
      ref.read(logProvider.notifier).warn('今日统计已重置');
    }
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.stats, required this.onReset});

  final StatsState stats;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    final weekday = [
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ][date.weekday - 1];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '数据看板',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${date.year}年${date.month}月${date.day}日 · $weekday  ·  今日已完成 ${stats.todayCount} 条',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: '重置今日统计',
          child: IconButton(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 19),
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.stats,
    required this.tasks,
    required this.failedCount,
  });

  final StatsState stats;
  final TasksState tasks;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '今日完成',
        '${stats.todayCount}',
        '条 EP',
        Icons.verified_rounded,
        AppTheme.success,
      ),
      (
        '待审核',
        '${tasks.totalPendingCount}',
        '条 EP',
        Icons.pending_actions_rounded,
        const Color(0xFFE09A23),
      ),
      (
        '视频时长',
        FormatUtils.formatTimeShort(stats.todayFrames),
        '累计',
        Icons.timer_outlined,
        AppTheme.primary,
      ),
      (
        '失败待处理',
        '$failedCount',
        '条 EP',
        Icons.report_gmailerrorred_outlined,
        AppTheme.danger,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 30) / 4;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: math.max(142, itemWidth).toDouble(),
                  child: _KpiCard(
                    label: item.$1,
                    value: item.$2,
                    unit: item.$3,
                    icon: item.$4,
                    color: item.$5,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        border: Border.all(color: const Color(0xFFE4E8EE)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E8EE)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DailyQuotePanel extends StatelessWidget {
  const _DailyQuotePanel({required this.state, required this.onRefresh});

  final DailyQuoteState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final quote = state.quote;
    return _Panel(
      title: '每日谏言',
      subtitle: state.failed ? '暂时无法连接谏言服务，正在展示本地寄语' : '来自一言的每日一句',
      trailing: Tooltip(
        message: '换一句',
        child: IconButton(
          onPressed: state.loading ? null : onRefresh,
          icon: state.loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          color: AppTheme.primary,
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: SizedBox(
        height: 142,
        child: quote == null
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 25,
                    color: Color(0xFFFFB638),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      quote.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (quote.sourceLabel.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '- ${quote.sourceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.completion,
    required this.stats,
    required this.pending,
    required this.failed,
  });
  final double completion;
  final StatsState stats;
  final int pending;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final percent = (completion * 100).round();
    return _Panel(
      title: '处理进度',
      subtitle: '今日已记录资源的完成情况',
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completion == 0 ? 0 : completion,
                      strokeWidth: 9,
                      backgroundColor: const Color(0xFFE9EDF2),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF36B37E),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Legend(
                      color: AppTheme.success,
                      label: '已完成',
                      value: '${stats.todayCount}',
                    ),
                    const SizedBox(height: 9),
                    _Legend(
                      color: const Color(0xFFE09A23),
                      label: '待审核',
                      value: '$pending',
                    ),
                    const SizedBox(height: 9),
                    _Legend(
                      color: AppTheme.danger,
                      label: '失败待处理',
                      value: '$failed',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: completion == 0 ? 0 : completion,
              minHeight: 7,
              backgroundColor: const Color(0xFFF0F2F5),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF36B37E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _TaskLoadPanel extends StatelessWidget {
  const _TaskLoadPanel({required this.tasks});
  final TasksState tasks;

  @override
  Widget build(BuildContext context) {
    final visible = [...tasks.tasks]
      ..sort((a, b) => b.notCheckCount.compareTo(a.notCheckCount));
    final maxPending = visible.fold<int>(
      1,
      (max, task) => max > task.notCheckCount ? max : task.notCheckCount,
    );
    return _Panel(
      title: '任务负载',
      subtitle: '按待审核数量排序',
      trailing: Text(
        '${visible.length} 个任务',
        style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
      ),
      child: visible.isEmpty
          ? const _QuietText('暂无任务数据')
          : Column(
              children: visible
                  .take(5)
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 106,
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: task.notCheckCount / maxPending,
                                minHeight: 7,
                                backgroundColor: const Color(0xFFF0F2F5),
                                valueColor: AlwaysStoppedAnimation(
                                  task.notCheckCount == 0
                                      ? AppTheme.success
                                      : const Color(0xFFFFB638),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${task.notCheckCount}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.entries});
  final List<LogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final recent = entries.reversed.take(5).toList();
    return _Panel(
      title: '最近事件',
      subtitle: '来自运行日志的最新记录',
      child: recent.isEmpty
          ? const _QuietText('暂无运行事件')
          : Column(
              children: recent
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: _logColor(entry.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            entry.timeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Color _logColor(LogType type) {
    switch (type) {
      case LogType.success:
        return AppTheme.success;
      case LogType.error:
        return AppTheme.danger;
      case LogType.warn:
      case LogType.pause:
        return AppTheme.warning;
      case LogType.auto:
        return AppTheme.primary;
      case LogType.info:
        return AppTheme.textTertiary;
    }
  }
}

class _QuietText extends StatelessWidget {
  const _QuietText(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        value,
        style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
      ),
    ),
  );
}
