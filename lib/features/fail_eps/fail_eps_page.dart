import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/tasks_provider.dart';

/// 验收失败 EP 页
class FailEpsPage extends ConsumerWidget {
  const FailEpsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(failEpsProvider);

    return Column(
      children: [
        _buildToolbar(ref, state),
        if (state.progressText.isNotEmpty ||
            (state.isLoading && state.progress > 0))
          _buildProgress(state),
        Expanded(child: _buildBody(context, ref, state)),
      ],
    );
  }

  Widget _buildToolbar(
    WidgetRef ref,
    FailEpsState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: Row(
        children: [
          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () => ref.read(failEpsProvider.notifier).scan(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              disabledBackgroundColor:
                  AppTheme.textTertiary.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                Text(
                  state.isLoading ? '扫描中...' : '获取验收失败EP',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (state.lastScanResult != null)
            Expanded(
              child: Text(
                '扫描 ${state.lastScanResult!.taskCount} 任务 / '
                '${state.lastScanResult!.jobCount} Job / '
                '${state.lastScanResult!.totalEps} EP',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(FailEpsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: state.progress / 100.0,
                backgroundColor: AppTheme.separator,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.progressText,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FailEpsState state,
  ) {
    if (state.isLoading && state.failedEps.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
          ),
        ),
      );
    }
    if (!state.loaded && state.failedEps.isEmpty) {
      return _buildHint();
    }
    if (state.failedEps.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: state.failedEps.length,
      itemBuilder: (context, index) {
        final ep = state.failedEps[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.danger.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'T${ep.taskId}-J${ep.jobId}-EP${ep.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ep.reason,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.danger,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(epOpenRequestProvider.notifier).request(ep.url);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: const Text(
                  '前往处理',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search, size: 48, color: AppTheme.textTertiary),
          SizedBox(height: 12),
          Text(
            '点击上方按钮获取验收失败 EP 列表',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            '将扫描所有任务的 Job 与 EP，按初筛人筛选',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, size: 48, color: AppTheme.success),
          SizedBox(height: 12),
          Text(
            '暂无验收失败 EP',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
