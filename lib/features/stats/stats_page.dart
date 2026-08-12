import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/log_provider.dart';
import '../../providers/stats_provider.dart';

/// 统计页
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      children: [
            // 今日完成数
            _buildStatCard(
              icon: Icons.verified,
              iconColor: AppTheme.success,
              label: '今日完成',
              value: '${stats.todayCount}',
              unit: '条',
            ),
            const SizedBox(height: 12),
            // 视频时长
            _buildStatCard(
              icon: Icons.schedule,
              iconColor: AppTheme.primary,
              label: '视频时长',
              value: FormatUtils.formatTime(stats.todayFrames),
              unit: '',
            ),
            const SizedBox(height: 24),
            // 重置按钮
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认重置'),
                    content: const Text('将重置今日完成数和视频时长统计，不可撤销'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('重置'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(statsProvider.notifier).reset();
                  ref.read(logProvider.notifier).warn('今日统计已重置');
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.danger,
                backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Text(
                '重置今日统计',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '统计说明',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• 完成数：今日成功审核的 EP 数量\n'
                    '• 视频时长：今日审核 EP 的视频总时长（按 30fps 换算）\n'
                    '• 统计按日重置，仅记录今日数据\n'
                    '• 标注成功后自动累加，3 秒内重复不计',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
