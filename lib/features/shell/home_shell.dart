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
import '../../providers/tasks_provider.dart';
import '../config/config_page.dart';
import '../fail_eps/fail_eps_page.dart';
import '../logs/logs_page.dart';
import '../stats/stats_page.dart';
import '../tasks/tasks_page.dart';
import '../webview/webview_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;

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
      return;
    }

    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).then((ok) {
      if (!ok) {
        ref.read(logProvider.notifier).warn('无法打开系统浏览器');
        launchUrl(Uri.parse(url));
      }
    });
    ref.read(logProvider.notifier).info('浏览器打开 EP');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tasks = ref.watch(tasksProvider);
    final failEps = ref.watch(failEpsProvider);
    final logs = ref.watch(logProvider);

    ref.listen<String?>(epOpenRequestProvider, (previous, url) {
      if (url == null) return;
      ref.read(epOpenRequestProvider.notifier).consume();
      final match = RegExp(r'/episodes/(\d+)/').firstMatch(url);
      final epId = match != null ? int.parse(match.group(1)!) : 0;
      _openEp(url, settings.epOpenMode, settings.cookie, epId);
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: AppTheme.surface,
          child: Row(
            children: [
              _buildSidebar(settings, tasks, failEps, logs),
              Container(width: 1, color: AppTheme.separatorLight),
              Expanded(child: pages[_selectedIndex]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(
    AppSettings settings,
    TasksState tasks,
    FailEpsState failEps,
    LogState logs,
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
        width: 160,
        color: AppTheme.sidebarBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部：交通灯 + Logo
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 16),
              child: Row(
                children: [
                  _TrafficLights(isMaximized: _isMaximized),
                  const Spacer(),
                ],
              ),
            ),
            // Logo
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD35A), Color(0xFFFFA400)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.warning.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.energy_savings_leaf,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 应用名称
            Center(
              child: Text(
                'zero_K-Genie',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 主导航项
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildNavItem(
                    icon: Icons.task_alt_outlined,
                    selectedIcon: Icons.task_alt,
                    label: '任务列表',
                    badge: tasks.totalPendingCount,
                    badgeColor: AppTheme.success,
                    index: 0,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    icon: Icons.error_outline,
                    selectedIcon: Icons.error,
                    label: '验收失败',
                    badge: failEps.failedEps.length,
                    badgeColor: AppTheme.danger,
                    index: 1,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: '日志',
                    index: 2,
                  ),
                  const SizedBox(height: 4),
                  _buildNavItem(
                    icon: Icons.pie_chart_outline,
                    selectedIcon: Icons.pie_chart,
                    label: '统计',
                    index: 3,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppTheme.separator,
                  ),
                  const SizedBox(height: 16),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: '系统设置',
                    index: 4,
                  ),
                ],
              ),
            ),
            // 底部操作
            _buildSidebarFooter(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    int badge = 0,
    Color? badgeColor,
  }) {
    final selected = index == _selectedIndex;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.sidebarSelection : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? AppTheme.textOnSelection : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.textOnSelection : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge > 0) _buildBadge(badge, badgeColor, selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count, Color? color, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.25)
            : (color ?? AppTheme.danger).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: selected ? AppTheme.textOnSelection : color ?? AppTheme.danger,
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 0.5,
            color: AppTheme.separator,
          ),
          const SizedBox(height: 8),
          _buildFooterAction(
            icon: Icons.code,
            label: 'GitHub',
            onTap: () {
              launchUrl(
                Uri.parse('https://github.com/Hongwei-name/Genie-Studio-App'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          _buildFooterAction(
            icon: Icons.info_outline,
            label: '关于',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD35A), Color(0xFFFFA400)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFA400).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.energy_savings_leaf,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'zero_K-Genie',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '智元标注审核助手',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '作者: zero_K',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    const size = 14.0;
    const gap = 10.0;

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
          hoverSymbol: '+',
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
              color: Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: isHovered
              ? Center(
                  child: Text(
                    hoverSymbol,
                    style: TextStyle(
                      fontSize: size * 0.58,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.58),
                      height: 1,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}







