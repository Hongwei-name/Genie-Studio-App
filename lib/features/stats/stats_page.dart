import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/log_provider.dart';
import '../../providers/stats_provider.dart';

/// Daily completion metrics.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final averageFrames = stats.todayCount == 0
        ? 0
        : stats.todayFrames ~/ stats.todayCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final metrics = [
          _Metric(
            icon: Icons.verified_outlined,
            color: AppTheme.success,
            label: '完成任务',
            value: '${stats.todayCount}',
            unit: '条',
          ),
          _Metric(
            icon: Icons.schedule_outlined,
            color: AppTheme.primary,
            label: '累计时长',
            value: FormatUtils.formatTime(stats.todayFrames),
          ),
          _Metric(
            icon: Icons.timelapse_outlined,
            color: AppTheme.warning,
            label: '平均时长',
            value: FormatUtils.formatTime(averageFrames),
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref),
                const SizedBox(height: 24),
                if (compact) ...[
                  for (final metric in metrics) ...[
                    _MetricTile(metric: metric),
                    const SizedBox(height: 10),
                  ],
                ] else
                  Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        Expanded(child: _MetricTile(metric: metrics[index])),
                        if (index < metrics.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                _buildSummary(stats.todayCount, stats.todayFrames),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: const Icon(
            Icons.pie_chart_outline,
            color: AppTheme.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今日统计',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(DateTime.now()),
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
            onPressed: () => _confirmReset(context, ref),
            icon: const Icon(Icons.restart_alt),
            color: AppTheme.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(int count, int frames) {
    final hasProgress = count > 0 || frames > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.separatorLight),
      ),
      child: Row(
        children: [
          Icon(
            hasProgress
                ? Icons.insights_outlined
                : Icons.hourglass_empty_outlined,
            color: hasProgress ? AppTheme.primary : AppTheme.textTertiary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasProgress
                  ? '已完成 $count 条任务，累计处理 ${FormatUtils.formatTime(frames)}'
                  : '今日尚无完成记录',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置今日统计'),
        content: const Text('完成任务、累计时长和平均时长将恢复为零。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(statsProvider.notifier).reset();
      ref.read(logProvider.notifier).warn('今日统计已重置');
    }
  }

  String _formatDate(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.year}年${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
  }
}

class _Metric {
  const _Metric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit = '',
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.separatorLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          const Spacer(),
          Text(
            metric.label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: metric.color,
                  ),
                ),
              ),
              if (metric.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  metric.unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
