import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/log_provider.dart';

/// 日志页
class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(logProvider);
    final entries = state.entries.reversed.toList();

    return Column(
      children: [
        _buildToolbar(ref),
        Expanded(
          child: entries.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final color = _colorForType(entry.type);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.timeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () => ref.read(logProvider.notifier).clear(),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: const Text(
              '清空',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(LogType type) {
    switch (type) {
      case LogType.success:
        return AppTheme.success;
      case LogType.error:
        return AppTheme.danger;
      case LogType.warn:
        return AppTheme.warning;
      case LogType.auto:
        return AppTheme.primary;
      case LogType.pause:
        return AppTheme.warning;
      case LogType.info:
        return AppTheme.textPrimary;
    }
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        '暂无日志',
        style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
      ),
    );
  }
}
