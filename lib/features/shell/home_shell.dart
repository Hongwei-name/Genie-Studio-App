import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart';
import '../../providers/app_providers.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/tasks_provider.dart';
import '../config/config_page.dart';
import '../fail_eps/fail_eps_page.dart';
import '../logs/logs_page.dart';
import '../stats/stats_page.dart';
import '../tasks/tasks_page.dart';
import '../webview/webview_page.dart';

/// macOS 风格主框架
/// - 无原生标题栏，自绘 macOS 交通灯 + 居中标题 + 可拖动
/// - 左侧边栏：一级导航 + 二级菜单（待审核展开显示任务列表）
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;
  bool _taskListExpanded = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(refreshProvider.notifier).restart();
      ref.read(tasksProvider.notifier).fetchTasks();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initWindowState() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  void _openEp(String url, EpOpenMode mode, String cookie, int episodeId) {
    if (mode == EpOpenMode.webview) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WebViewPage(
            url: url,
            cookie: cookie,
            episodeId: episodeId,
          ),
        ),
      );
      ref.read(logProvider.notifier).info('WebView 打开 EP');
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
          .then((ok) {
        if (!ok) {
          ref.read(logProvider.notifier).warn('无法打开系统浏览器');
          launchUrl(Uri.parse(url));
        }
      });
      ref.read(logProvider.notifier).info('浏览器打开 EP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(statsProvider);
    final tasks = ref.watch(tasksProvider);
    final failEps = ref.watch(failEpsProvider);
    final logs = ref.watch(logProvider);

    ref.listen<String?>(epOpenRequestProvider, (previous, url) {
      if (url != null) {
        ref.read(epOpenRequestProvider.notifier).consume();
        final match = RegExp(r'/episodes/(\d+)/').firstMatch(url);
        final epId = match != null ? int.parse(match.group(1)!) : 0;
        _openEp(url, settings.epOpenMode, settings.cookie, epId);
      }
    });

    final pages = <Widget>[
      const TasksPage(),
      const FailEpsPage(),
      const LogsPage(),
      const StatsPage(),
      const ConfigPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: AppTheme.windowBackground,
          child: Column(
            children: [
              _buildTitleBar(settings, stats, tasks),
              Expanded(
                child: Row(
                  children: [
                    _buildSidebar(settings, tasks, failEps, logs),
                    Container(width: 1, color: AppTheme.separator),
                    Expanded(child: pages[_selectedIndex]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ macOS 标题栏 ═══════════════

  Widget _buildTitleBar(
    AppSettings settings,
    StatsState stats,
    TasksState tasks,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.restore();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 38,
        color: AppTheme.sidebarBackground,
        child: Row(
          children: [
            _buildTitleBarLeft(settings),
            _buildTitleBarRight(stats, tasks),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBarLeft(AppSettings settings) {
    return Expanded(
      child: Row(
        children: [
          const SizedBox(width: 12),
          _TrafficLights(isMaximized: _isMaximized),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: Text(
                '智元标注审核助手',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          if (settings.isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: const Text(
                '已暂停',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildTitleBarRight(StatsState stats, TasksState tasks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statChip('完成', '${stats.todayCount}', AppTheme.success),
          const SizedBox(width: 14),
          _statChip('时长', stats.timeShort, AppTheme.primary),
          const SizedBox(width: 14),
          _statChip('待审', '${tasks.totalPendingCount}', AppTheme.danger),
          const SizedBox(width: 8),
          if (tasks.isLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: () =>
                  ref.read(tasksProvider.notifier).fetchTasks(),
              tooltip: '刷新',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═══════════════ 侧边栏（一级 + 二级菜单） ═══════════════

  Widget _buildSidebar(
    AppSettings settings,
    TasksState tasks,
    FailEpsState failEps,
    LogState logs,
  ) {
    return Container(
      width: 200,
      color: AppTheme.sidebarBackground,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              children: [
                // 一级导航：待审核（带折叠箭头）
                _buildNavItemWithToggle(
                  icon: Icons.inbox_outlined,
                  selectedIcon: Icons.inbox,
                  label: '待审核',
                  badge: tasks.totalPendingCount,
                  badgeColor: AppTheme.danger,
                  index: 0,
                  isExpanded: _taskListExpanded,
                  onToggle: () => setState(() {
                    _taskListExpanded = !_taskListExpanded;
                    if (_selectedIndex != 0) _selectedIndex = 0;
                  }),
                ),
                // 二级菜单：任务列表（可折叠）
                if (_selectedIndex == 0 && _taskListExpanded)
                  _buildTaskListSection(tasks),
                _buildPrimaryNavItem(
                  icon: Icons.error_outline,
                  selectedIcon: Icons.error,
                  label: '验收失败',
                  badge: failEps.failedEps.length,
                  badgeColor: AppTheme.warning,
                  index: 1,
                ),
                _buildPrimaryNavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: '日志',
                  badge: logs.entries.length,
                  badgeColor: AppTheme.textTertiary,
                  index: 2,
                ),
                _buildPrimaryNavItem(
                  icon: Icons.pie_chart_outline,
                  selectedIcon: Icons.pie_chart,
                  label: '统计',
                  index: 3,
                ),
                _buildPrimaryNavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: '配置',
                  index: 4,
                ),
              ],
            ),
          ),
          _buildSidebarFooter(settings),
        ],
      ),
    );
  }

  /// 一级导航项
  Widget _buildPrimaryNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    int badge = 0,
    Color? badgeColor,
  }) {
    final selected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.sidebarSelection : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 16,
                  color: selected
                      ? AppTheme.textOnSelection
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected
                          ? AppTheme.textOnSelection
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (badge > 0)
                  _buildNavBadge(badge, badgeColor, selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 带折叠箭头的一级导航项
  Widget _buildNavItemWithToggle({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isExpanded,
    required VoidCallback onToggle,
    int badge = 0,
    Color? badgeColor,
  }) {
    final selected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () {
            setState(() => _selectedIndex = index);
            if (!isExpanded) onToggle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.sidebarSelection : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 16,
                  color: selected
                      ? AppTheme.textOnSelection
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected
                          ? AppTheme.textOnSelection
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (badge > 0)
                  _buildNavBadge(badge, badgeColor, selected),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedRotation(
                    turns: isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: selected
                          ? AppTheme.textOnSelection.withValues(alpha: 0.7)
                          : AppTheme.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 二级菜单：任务列表（嵌入侧边栏，与主菜单风格统一）
  Widget _buildTaskListSection(TasksState tasks) {
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 4, top: 2, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 二级标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                const Text(
                  '任务',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tasks.tasks.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 任务列表
          if (tasks.isLoading && tasks.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            )
          else if (tasks.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无任务',
                style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: tasks.tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks.tasks[index];
                  final isSelected = task.id == selectedTaskId;
                  final isLoading = tasks.loadingTasks.contains(task.id);
                  final error = tasks.taskErrors[task.id];
                  final jobs = tasks.jobsByTask[task.id];

                  var epCount = 0;
                  if (jobs != null) {
                    for (final j in jobs) {
                      for (final jid in j.displayJobIds) {
                        final eps = tasks.epsByJob['${task.id}_$jid'];
                        if (eps != null) epCount += eps.length;
                      }
                    }
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedTaskIdProvider.notifier).state =
                            task.id;
                        ref
                            .read(tasksProvider.notifier)
                            .toggleExpand(task.id, isExpanded: true);
                      },
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.sidebarSelection.withValues(alpha: 0.5)
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXs),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? AppTheme.textPrimary
                                          : AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '#${task.id}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (isLoading)
                                        const Text(
                                          '加载中',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.primary,
                                          ),
                                        )
                                      else if (error != null)
                                        const Text(
                                          '失败',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.danger,
                                          ),
                                        )
                                      else if (jobs != null)
                                        Text(
                                          '$epCount EP',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (task.notCheckCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusXs),
                                ),
                                child: Text(
                                  '${task.notCheckCount}',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavBadge(int count, Color? color, bool selected) {
    if (selected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textOnSelection,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.danger).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color ?? AppTheme.danger,
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(AppSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.separator.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '并发 ${settings.concurrency}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            settings.autoOpen ? '自动打开: 开' : '自动打开: 关',
            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ 交通灯组件 ═══════════════

class _TrafficLights extends StatefulWidget {
  const _TrafficLights({required this.isMaximized});

  final bool isMaximized;

  @override
  State<_TrafficLights> createState() => _TrafficLightsState();
}

class _TrafficLightsState extends State<_TrafficLights> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    const gap = 8.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLight(
          index: 0,
          color: AppTheme.trafficClose,
          hoverSymbol: '×',
          onTap: () => windowManager.close(),
          size: size,
        ),
        const SizedBox(width: gap),
        _buildLight(
          index: 1,
          color: AppTheme.trafficMinimize,
          hoverSymbol: '−',
          onTap: () => windowManager.minimize(),
          size: size,
        ),
        const SizedBox(width: gap),
        _buildLight(
          index: 2,
          color: widget.isMaximized
              ? AppTheme.textTertiary.withValues(alpha: 0.5)
              : AppTheme.trafficZoom,
          hoverSymbol: widget.isMaximized ? '+' : '−',
          onTap: () async {
            if (widget.isMaximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
          },
          size: size,
        ),
      ],
    );
  }

  Widget _buildLight({
    required int index,
    required Color color,
    required String hoverSymbol,
    required VoidCallback onTap,
    required double size,
  }) {
    final isHovered = _hoveredIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: isHovered
              ? Center(
                  child: Text(
                    hoverSymbol,
                    style: TextStyle(
                      fontSize: size * 0.6,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.6),
                      height: 1.0,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
