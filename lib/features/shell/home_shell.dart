import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_tray_manager.dart';
import '../../data/models/app_settings.dart';
import '../../providers/app_providers.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/local_http_server_provider.dart';
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

  static const _navItems = [
    (Icons.grid_view_rounded, '工作台'),
    (Icons.report_gmailerrorred_outlined, '失败 EP'),
    (Icons.subject_rounded, '运行日志'),
    (Icons.insights_rounded, '数据统计'),
    (Icons.tune_rounded, '偏好设置'),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(refreshProvider.notifier).restart();
      ref.read(tasksProvider.notifier).fetchTasks();
      ref.read(localHttpServerProvider).start();
      AppTrayManager().init();
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

  @override
  void onWindowClose() async => windowManager.hide();

  void _openEp(String url, EpOpenMode mode, String cookie, int episodeId) {
    if (mode == EpOpenMode.webview) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WebViewPage(url: url, cookie: cookie, episodeId: episodeId),
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

    ref.listen<String?>(epOpenRequestProvider, (previous, url) {
      if (url == null) return;
      ref.read(epOpenRequestProvider.notifier).consume();
      final match = RegExp(r'/episodes/(\d+)/').firstMatch(url);
      final epId = match == null ? 0 : int.parse(match.group(1)!);
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFFF4F6F9),
          child: Column(
            children: [
              _WindowBar(
                title: _navItems[_selectedIndex].$2,
                isMaximized: _isMaximized,
              ),
              Expanded(
                child: Row(
                  children: [
                    _NavigationRail(
                      selectedIndex: _selectedIndex,
                      onSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      tasks: tasks,
                      failEps: failEps,
                      onAbout: _showAbout,
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 0, 14, 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E7ED)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: pages[_selectedIndex],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('zero_K-Genie'),
        content: const Text('zero_K-Genie\nv3.0.0\n\n让审核工作回到清晰、可控的节奏。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _WindowBar extends StatelessWidget {
  const _WindowBar({required this.title, required this.isMaximized});

  final String title;
  final bool isMaximized;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (isMaximized) {
          await windowManager.restore();
        } else {
          await windowManager.maximize();
        }
      },
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            const SizedBox(width: 20),
            const _TrafficLights(),
            const SizedBox(width: 22),
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFFFA21A)),
            const SizedBox(width: 8),
            const Text(
              'zero_K-Genie',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: const Color(0xFFD7DCE3)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFE3E7ED)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 14,
                    color: AppTheme.success,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '本地服务在线',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.tasks,
    required this.failEps,
    required this.onAbout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final TasksState tasks;
  final FailEpsState failEps;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _RailLogo(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _HomeShellState._navItems.length,
              itemBuilder: (context, index) {
                final item = _HomeShellState._navItems[index];
                final badge = index == 0
                    ? tasks.totalPendingCount
                    : index == 1
                    ? failEps.failedEps.length
                    : 0;
                return _RailItem(
                  icon: item.$1,
                  label: item.$2,
                  selected: selectedIndex == index,
                  badge: badge,
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFDDE2E9),
          ),
          _RailAction(
            icon: Icons.info_outline_rounded,
            label: '关于',
            onTap: onAbout,
          ),
          _RailAction(
            icon: Icons.open_in_new_rounded,
            label: '源码',
            onTap: () => launchUrl(
              Uri.parse('https://github.com/Hongwei-name/Genie-Studio-App'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB526),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB526).withValues(alpha: .25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 62,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF2D8) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: const Color(0xFFFFD990))
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: selected
                          ? const Color(0xFFB86A00)
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF9A5D00)
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (badge > 0)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE9A326)
                            : const Color(0xFFE6574E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: AppTheme.textTertiary,
      ),
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Light(
          color: AppTheme.trafficClose,
          symbol: '×',
          onTap: () => windowManager.hide(),
        ),
        const SizedBox(width: 8),
        _Light(
          color: AppTheme.trafficMinimize,
          symbol: '−',
          onTap: () => windowManager.minimize(),
        ),
        const SizedBox(width: 8),
        _Light(
          color: AppTheme.trafficZoom,
          symbol: '+',
          onTap: () async {
            final maximized = await windowManager.isMaximized();
            if (maximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
          },
        ),
      ],
    );
  }
}

class _Light extends StatefulWidget {
  const _Light({
    required this.color,
    required this.symbol,
    required this.onTap,
  });

  final Color color;
  final String symbol;
  final VoidCallback onTap;

  @override
  State<_Light> createState() => _LightState();
}

class _LightState extends State<_Light> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: .08)),
          ),
          alignment: Alignment.center,
          child: hover
              ? Text(
                  widget.symbol,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: Colors.black54,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
