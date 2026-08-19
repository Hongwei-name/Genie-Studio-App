import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/episode.dart';
import '../../data/repositories/review_repository.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/tasks_provider.dart';

/// 验收失败 EP 页面。
class FailEpsPage extends ConsumerStatefulWidget {
  const FailEpsPage({super.key});

  @override
  ConsumerState<FailEpsPage> createState() => _FailEpsPageState();
}

class _FailEpsPageState extends ConsumerState<FailEpsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(failEpsProvider);
    final result = state.lastScanResult;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      interactive: true,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(state, result)),
          if (state.progressText.isNotEmpty ||
              (state.isLoading && state.progress > 0))
            SliverToBoxAdapter(child: _buildProgress(state)),
          _buildBody(state),
        ],
      ),
    );
  }

  Widget _buildHeader(FailEpsState state, ScanResult? result) {
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
                    Text(
                      '验收失败',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '集中查看需要重新处理的 EP，扫描结果会按照当前筛选条件更新。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(failEpsProvider.notifier).scan(),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.radar, size: 17),
                label: Text(state.isLoading ? '扫描中' : '重新扫描'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatCard(
                    label: '任务',
                    value: result?.taskCount ?? 0,
                    icon: Icons.assignment_outlined,
                    color: AppTheme.primary,
                    width: itemWidth,
                  ),
                  _StatCard(
                    label: 'Job',
                    value: result?.jobCount ?? 0,
                    icon: Icons.work_outline,
                    color: AppTheme.warning,
                    width: itemWidth,
                  ),
                  _StatCard(
                    label: '扫描 EP',
                    value: result?.totalEps ?? 0,
                    icon: Icons.video_library_outlined,
                    color: AppTheme.textSecondary,
                    width: itemWidth,
                  ),
                  _StatCard(
                    label: '待处理',
                    value: state.failedEps.length,
                    icon: Icons.error_outline,
                    color: AppTheme.danger,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(FailEpsState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: state.progress / 100,
                minHeight: 4,
                backgroundColor: AppTheme.separatorLight,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            state.progressText,
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FailEpsState state) {
    if (state.isLoading && state.failedEps.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.primary,
          ),
        ),
      );
    }
    if (!state.loaded && state.failedEps.isEmpty) {
      return _emptyBody(Icons.radar, '还没有扫描结果', '点击右上角“重新扫描”获取验收失败 EP。');
    }
    if (state.failedEps.isEmpty) {
      return _emptyBody(
        Icons.check_circle_outline,
        '当前没有验收失败 EP',
        '太好了，当前筛选范围内的 EP 都已通过验收。',
        color: AppTheme.success,
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 18, 20, 24),
      sliver: SliverList.separated(
        itemCount: state.failedEps.length,
        itemBuilder: (context, index) => _FailedEpCard(
          ep: state.failedEps[index],
          onOpen: () => ref
              .read(epOpenRequestProvider.notifier)
              .request(state.failedEps[index].url),
        ),
        separatorBuilder: (context, index) => const SizedBox(height: 9),
      ),
    );
  }

  Widget _emptyBody(
    IconData icon,
    String title,
    String description, {
    Color color = AppTheme.textTertiary,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.separatorLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: color),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.windowBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedEpCard extends StatelessWidget {
  const _FailedEpCard({required this.ep, required this.onOpen});

  final FailedEpisode ep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.separatorLight),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              size: 19,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EP ${ep.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Task ${ep.taskId}  ·  Job ${ep.jobId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  ep.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('处理'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }
}
