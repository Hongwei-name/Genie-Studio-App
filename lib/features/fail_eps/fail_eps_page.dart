import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/review_repository.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/tasks_provider.dart';

/// 验收失败 EP 页面。
class FailEpsPage extends ConsumerWidget {
  const FailEpsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(failEpsProvider);
    final result = state.lastScanResult;
    return Column(
      children: [
        _buildHeader(ref, state, result),
        if (state.progressText.isNotEmpty || (state.isLoading && state.progress > 0))
          _buildProgress(state),
        Expanded(child: _buildBody(context, ref, state)),
      ],
    );
  }

  Widget _buildHeader(WidgetRef ref, FailEpsState state, ScanResult? result) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.separatorLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('验收失败', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    SizedBox(height: 5),
                    Text('集中查看需要重新处理的 EP，扫描结果会按照当前筛选条件更新。', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: state.isLoading ? null : () => ref.read(failEpsProvider.notifier).scan(),
                icon: state.isLoading
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.radar, size: 17),
                label: Text(state.isLoading ? '扫描中' : '重新扫描'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat('任务', result?.taskCount ?? 0, Icons.assignment_outlined, AppTheme.primary),
              _stat('Job', result?.jobCount ?? 0, Icons.work_outline, AppTheme.warning),
              _stat('扫描 EP', result?.totalEps ?? 0, Icons.video_library_outlined, AppTheme.textSecondary),
              _stat('待处理', state.failedEps.length, Icons.error_outline, AppTheme.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.windowBackground, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              const SizedBox(height: 2),
              Text('$value', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(FailEpsState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      color: AppTheme.surface,
      child: Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: state.progress / 100, minHeight: 4, backgroundColor: AppTheme.separatorLight, valueColor: const AlwaysStoppedAnimation(AppTheme.primary)))),
        const SizedBox(width: 10),
        Text(state.progressText, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, FailEpsState state) {
    if (state.isLoading && state.failedEps.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary));
    }
    if (!state.loaded && state.failedEps.isEmpty) return _emptyState(Icons.radar, '还没有扫描结果', '点击右上角“重新扫描”获取验收失败 EP。');
    if (state.failedEps.isEmpty) return _emptyState(Icons.check_circle_outline, '当前没有验收失败 EP', '太好了，当前筛选范围内的 EP 都已通过验收。', color: AppTheme.success);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      itemCount: state.failedEps.length,
      itemBuilder: (context, index) {
        final ep = state.failedEps[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radius), border: Border.all(color: AppTheme.separatorLight)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(AppTheme.radiusSm)), child: const Icon(Icons.priority_high_rounded, size: 19, color: AppTheme.danger)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EP ${ep.id}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('Task ${ep.taskId}  ·  Job ${ep.jobId}', style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              const SizedBox(height: 7),
              Text(ep.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
            ])),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () => ref.read(epOpenRequestProvider.notifier).request(ep.url), icon: const Icon(Icons.open_in_new, size: 15), label: const Text('处理'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger))),
          ]),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String desc, {Color color = AppTheme.textTertiary}) {
    return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34), margin: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(AppTheme.radius), border: Border.all(color: AppTheme.separatorLight)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 42, color: color), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)), const SizedBox(height: 6), Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))])));
  }
}
