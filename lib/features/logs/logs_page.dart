import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/log_provider.dart';

enum _LogFilter { all, info, success, warning, error, automation, paused }

/// Searchable, filterable view of the in-memory activity log.
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  _LogFilter _filter = _LogFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logProvider);
    final query = _searchController.text.trim().toLowerCase();
    final entries = state.entries.reversed.where((entry) {
      return _matchesFilter(entry.type) &&
          (query.isEmpty || entry.message.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: [
        _buildHeader(context, entries.length, state.entries.length),
        Expanded(
          child: entries.isEmpty
              ? _buildEmpty(query.isNotEmpty || _filter != _LogFilter.all)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) =>
                      _LogRow(entry: entries[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int visibleCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.separatorLight)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppTheme.primary,
                size: 21,
              ),
              const SizedBox(width: 8),
              const Text(
                '运行日志',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$visibleCount / $totalCount',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: '清空日志',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.danger,
                  onPressed: totalCount == 0
                      ? null
                      : () => _confirmClear(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '搜索日志内容',
                    prefixIcon: Icon(Icons.search, size: 19),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: '日志级别',
                child: PopupMenuButton<_LogFilter>(
                  initialValue: _filter,
                  onSelected: (filter) => setState(() => _filter = filter),
                  itemBuilder: (context) => _LogFilter.values
                      .map(
                        (filter) => PopupMenuItem(
                          value: filter,
                          child: Text(_filterLabel(filter)),
                        ),
                      )
                      .toList(),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _filter == _LogFilter.all
                          ? AppTheme.surfaceHover
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: _filter == _LogFilter.all
                              ? AppTheme.textSecondary
                              : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filterLabel(_filter),
                          style: TextStyle(
                            fontSize: 12,
                            color: _filter == _LogFilter.all
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空运行日志'),
        content: const Text('此操作会移除当前会话中的全部日志。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(logProvider.notifier).clear();
  }

  bool _matchesFilter(LogType type) {
    return switch (_filter) {
      _LogFilter.all => true,
      _LogFilter.info => type == LogType.info,
      _LogFilter.success => type == LogType.success,
      _LogFilter.warning => type == LogType.warn,
      _LogFilter.error => type == LogType.error,
      _LogFilter.automation => type == LogType.auto,
      _LogFilter.paused => type == LogType.pause,
    };
  }

  String _filterLabel(_LogFilter filter) {
    return switch (filter) {
      _LogFilter.all => '全部',
      _LogFilter.info => '信息',
      _LogFilter.success => '成功',
      _LogFilter.warning => '警告',
      _LogFilter.error => '错误',
      _LogFilter.automation => '自动',
      _LogFilter.paused => '暂停',
    };
  }

  Widget _buildEmpty(bool hasFilter) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter
                ? Icons.manage_search_outlined
                : Icons.receipt_long_outlined,
            size: 34,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            hasFilter ? '未找到匹配的日志' : '暂无运行日志',
            style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(entry.type);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.separatorLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppTheme.radius),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeTag(type: entry.type, color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    entry.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(LogType type) {
    return switch (type) {
      LogType.success => AppTheme.success,
      LogType.error => AppTheme.danger,
      LogType.warn || LogType.pause => AppTheme.warning,
      LogType.auto => AppTheme.primary,
      LogType.info => AppTheme.textSecondary,
    };
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, required this.color});

  final LogType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        switch (type) {
          LogType.info => '信息',
          LogType.success => '成功',
          LogType.error => '错误',
          LogType.warn => '警告',
          LogType.auto => '自动',
          LogType.pause => '暂停',
        },
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
