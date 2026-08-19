import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/stats_provider.dart';

/// 配置页面
/// 包含 Token（Cookie）配置、刷新、自动打开、并发数、EP 打开方式等
class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  late TextEditingController _cookieCtrl;
  late TextEditingController _refreshCtrl;
  late TextEditingController _screenerCtrl;
  late TextEditingController _concurrencyCtrl;
  late int _concurrency;
  late EpOpenMode _epOpenMode;
  late bool _autoOpen;
  late bool _showAllJobs;
  bool _obscureCookie = true;
  bool _isLoggingIn = false;
  bool _isInstallingUserscript = false;
  WebviewController? _webviewController;
  StreamSubscription<String>? _loginUrlSub;
  BuildContext? _loginDialogContext;
  bool _loginDialogOpen = false;
  bool _extractingLoginCookie = false;
  bool _loginRedirected = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _cookieCtrl = TextEditingController(text: s.cookie);
    _refreshCtrl = TextEditingController(text: '${s.refreshIntervalSeconds}');
    _screenerCtrl = TextEditingController(text: s.screener);
    _concurrency = s.concurrency < AppConfig.minConcurrency
        ? AppConfig.minConcurrency
        : s.concurrency;
    _concurrencyCtrl = TextEditingController(text: '$_concurrency');
    _epOpenMode = s.epOpenMode;
    _autoOpen = s.autoOpen;
    _showAllJobs = s.showAllJobs;
  }

  @override
  void dispose() {
    _cancelLoginSession();
    _cookieCtrl.dispose();
    _refreshCtrl.dispose();
    _screenerCtrl.dispose();
    _concurrencyCtrl.dispose();
    _webviewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '系统设置',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '管理连接、自动化行为与本地数据维护',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(settings.cookie.isNotEmpty, settings.isPaused),
            ],
          ),
          const SizedBox(height: 22),

          // 两列布局
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左列
              Expanded(
                child: Column(
                  children: [
                    // 认证部分
                    _buildSection(
                      title: '认证',
                      children: [
                        _buildCookieRow(),
                        if (settings.cookie.isEmpty) _buildLoginButton(),
                      ],
                    ),

                    // 刷新设置
                    _buildSection(
                      title: '刷新设置',
                      children: [
                        _buildRefreshRow(),
                        _buildSwitchRow(
                          label: '暂停刷新',
                          desc: '暂停任务列表自动刷新',
                          value: ref.watch(settingsProvider).isPaused,
                          onChanged: (v) => _togglePause(v),
                        ),
                      ],
                    ),

                    // 并发与性能
                    _buildSection(
                      title: '并发与性能',
                      children: [_buildConcurrencyRow()],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // 右列
              Expanded(
                child: Column(
                  children: [
                    // 自动打开
                    _buildSection(
                      title: '自动打开',
                      children: [
                        _buildSwitchRow(
                          label: '自动打开新EP',
                          desc: '仅自动打开未打开、非验收失败的普通EP',
                          value: _autoOpen,
                          onChanged: (v) => setState(() => _autoOpen = v),
                        ),
                        _buildEpOpenModeRow(),
                      ],
                    ),

                    // 浏览器脚本
                    _buildSection(
                      title: '浏览器脚本',
                      children: [_buildUserscriptInstallRow()],
                    ),

                    // 验收失败筛选
                    _buildSection(
                      title: '验收失败筛选',
                      children: [
                        _buildScreenerRow(),
                        _buildSwitchRow(
                          label: '显示所有Job',
                          desc: '关闭时只显示有待审核EP的Job',
                          value: _showAllJobs,
                          onChanged: (v) => setState(() => _showAllJobs = v),
                        ),
                      ],
                    ),

                    // 统计与日志
                    _buildSection(
                      title: '统计与日志',
                      children: [
                        _buildActionRow(
                          label: '重置今日统计',
                          desc: '重置今日完成数和视频时长',
                          buttonText: '重置',
                          isDestructive: true,
                          onTap: _resetStats,
                        ),
                        _buildActionRow(
                          label: '清空日志',
                          desc: '清空所有日志记录',
                          buttonText: '清空',
                          onTap: _clearLogs,
                        ),
                        _buildActionRow(
                          label: '重新扫描验收失败EP',
                          desc: '清空缓存并重新扫描所有任务',
                          buttonText: '扫描',
                          isDestructive: true,
                          onTap: _rescanFailEps,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 保存按钮
          Center(
            child: SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: const Text('保存配置'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool authenticated, bool paused) {
    final color = authenticated ? AppTheme.success : AppTheme.warning;
    final label = authenticated
        ? (paused ? '已认证 · 已暂停' : '已认证 · 运行中')
        : '等待 Cookie';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            authenticated ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.separatorLight),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppTheme.separator,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cookie 配置行（核心）
  Widget _buildCookieRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Token (Cookie)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _obscureCookie = !_obscureCookie),
                child: Icon(
                  _obscureCookie ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cookieCtrl,
            obscureText: _obscureCookie,
            maxLines: _obscureCookie ? 1 : 2,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '粘贴 Cookie 或点击下方按钮登录获取',
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.surfaceHover,
            ),
          ),
        ],
      ),
    );
  }

  /// 登录按钮（当 Cookie 为空时显示）
  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _isLoggingIn ? null : _openLoginWebView,
              icon: _isLoggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(_isLoggingIn ? '登录中...' : '点击登录获取 Cookie'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方按钮打开登录页面，登录完成后将自动获取 Cookie',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  /// 打开登录 WebView
  Future<void> _openLoginWebView() async {
    if (_isLoggingIn || !mounted) return;
    setState(() => _isLoggingIn = true);

    try {
      final controller = WebviewController();
      _webviewController = controller;
      _loginDialogOpen = true;
      _extractingLoginCookie = false;
      _loginRedirected = false;
      await controller.initialize();

      // 监听 URL 变化，检测登录完成
      _loginUrlSub = controller.url.listen((url) {
        if (_loginDialogOpen &&
            !_extractingLoginCookie &&
            !url.contains('/login')) {
          // 登录完成，提取 Cookie
          _loginRedirected = true;
          if (_loginDialogContext != null) {
            _extractCookieAndClose();
          }
        }
      });

      // 打开登录页面
      await controller.loadUrl('https://tgs-geniestudio.agibot.com/login/gxcy');

      if (!mounted) return;

      // 显示 WebView 对话框
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          _loginDialogContext = ctx;
          if (_loginRedirected) {
            Future<void>.microtask(_extractCookieAndClose);
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 600,
              height: 500,
              child: Column(
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.separator),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _closeLoginDialog(ctx),
                        ),
                      ],
                    ),
                  ),
                  // WebView
                  Expanded(child: Webview(controller)),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ref.read(logProvider.notifier).error('登录失败: $e');
        _showToast('登录失败: $e');
      }
    } finally {
      _cancelLoginSession();
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  /// 提取 Cookie 并关闭对话框
  Future<void> _extractCookieAndClose() async {
    if (!_loginDialogOpen ||
        _extractingLoginCookie ||
        _webviewController == null ||
        _loginDialogContext == null) {
      return;
    }
    _extractingLoginCookie = true;

    try {
      // 执行 JavaScript 获取 Cookie
      final result = await _webviewController!.executeScript('document.cookie');
      if (result != null && result.toString().isNotEmpty) {
        final cookie = result.toString();
        if (!mounted) return;
        _cookieCtrl.text = cookie;

        // 自动保存
        await _save();

        if (!mounted || !_loginDialogOpen) return;
        final dialogContext = _loginDialogContext;
        _loginDialogOpen = false;
        if (dialogContext != null && dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        _showToast('Cookie 获取成功！');
        ref.read(logProvider.notifier).success('登录成功，Cookie 已获取');
      }
    } catch (e) {
      if (mounted) {
        ref.read(logProvider.notifier).error('提取 Cookie 失败: $e');
      }
    } finally {
      _extractingLoginCookie = false;
    }
  }

  void _closeLoginDialog(BuildContext dialogContext) {
    _loginDialogOpen = false;
    _loginRedirected = false;
    _loginUrlSub?.cancel();
    _loginUrlSub = null;
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
  }

  void _cancelLoginSession() {
    _loginDialogOpen = false;
    _extractingLoginCookie = false;
    _loginRedirected = false;
    _loginDialogContext = null;
    _loginUrlSub?.cancel();
    _loginUrlSub = null;
    _webviewController?.dispose();
    _webviewController = null;
  }

  Widget _buildRefreshRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Text(
            '刷新频率',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            height: 32,
            child: TextField(
              controller: _refreshCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.surfaceHover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '秒',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConcurrencyRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '并发数',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '同时打开的 EP 数量',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _buildCounterButton(
                icon: Icons.remove,
                onTap: () {
                  if (_concurrency > AppConfig.minConcurrency) {
                    _setConcurrency(_concurrency - 1);
                  }
                },
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 64,
                height: 32,
                child: TextField(
                  controller: _concurrencyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceHover,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null &&
                        parsed >= AppConfig.minConcurrency &&
                        parsed != _concurrency) {
                      setState(() => _concurrency = parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              _buildCounterButton(
                icon: Icons.add,
                onTap: () {
                  _setConcurrency(_concurrency + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setConcurrency(int value) {
    final normalized = value < AppConfig.minConcurrency
        ? AppConfig.minConcurrency
        : value;
    setState(() {
      _concurrency = normalized;
      _concurrencyCtrl.value = TextEditingValue(
        text: '$normalized',
        selection: TextSelection.collapsed(offset: '$normalized'.length),
      );
    });
  }

  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHover,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildEpOpenModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Text(
            'EP 打开方式',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          SegmentedButton<EpOpenMode>(
            segments: const [
              ButtonSegment(
                value: EpOpenMode.browser,
                label: Text('浏览器', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: EpOpenMode.webview,
                label: Text('WebView', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_epOpenMode},
            onSelectionChanged: (v) => setState(() => _epOpenMode = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserscriptInstallRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '安装脚本猫并配置脚本',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '打开官网和当前版本脚本安装页',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _isInstallingUserscript ? null : _installUserscript,
            icon: _isInstallingUserscript
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_browser_outlined, size: 16),
            label: Text(
              _isInstallingUserscript ? '打开中...' : '一键安装',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: .3)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '初筛人',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '（可选）',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _screenerCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: '输入初筛人姓名',
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.surfaceHover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String label,
    required String desc,
    required String buttonText,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: isDestructive
                  ? AppTheme.danger
                  : AppTheme.primary,
              backgroundColor: isDestructive
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.surfaceHover,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 操作 ==========

  Future<void> _togglePause(bool paused) async {
    await ref.read(refreshProvider.notifier).togglePause();
    ref.read(logProvider.notifier).info(paused ? '已暂停刷新' : '已恢复刷新');
  }

  Future<void> _installUserscript() async {
    if (_isInstallingUserscript) return;
    setState(() => _isInstallingUserscript = true);

    try {
      final managerOpened = await launchUrl(
        Uri.parse(AppConfig.scriptCatInstallUrl),
        mode: LaunchMode.externalApplication,
      );
      // Give the browser a moment to create the first tab before opening the
      // script URL in a second tab.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final scriptOpened = await launchUrl(
        Uri.parse(AppConfig.userscriptInstallUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (managerOpened && scriptOpened) {
        _showToast('已打开脚本猫官网和脚本安装页。请先安装扩展，再在脚本页确认安装。');
        ref.read(logProvider.notifier).success('已打开脚本猫安装页和 zero_K-Genie 脚本配置页');
      } else {
        _showToast('无法打开系统浏览器，请检查默认浏览器设置。');
        ref.read(logProvider.notifier).error('打开脚本猫安装页失败');
      }
    } catch (e) {
      ref.read(logProvider.notifier).error('打开脚本猫安装页失败: $e');
      if (mounted) _showToast('打开脚本猫安装页失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _isInstallingUserscript = false);
    }
  }

  Future<void> _save() async {
    // 解析刷新频率
    var seconds = int.tryParse(_refreshCtrl.text.trim()) ?? 0;
    if (seconds < 0) seconds = 0;
    if (seconds > 600) seconds = 600;
    final newInterval = seconds * 1000;

    final parsedConcurrency = int.tryParse(_concurrencyCtrl.text.trim());
    final newConcurrency =
        parsedConcurrency == null ||
            parsedConcurrency < AppConfig.minConcurrency
        ? AppConfig.minConcurrency
        : parsedConcurrency;
    if (newConcurrency != _concurrency ||
        _concurrencyCtrl.text != '$newConcurrency') {
      _setConcurrency(newConcurrency);
    }

    final currentSettings = ref.read(settingsProvider);
    final effectiveInterval = currentSettings.isPaused ? 0 : newInterval;
    final newSettings = currentSettings.copyWith(
      cookie: _cookieCtrl.text.trim(),
      refreshInterval: effectiveInterval,
      resumeRefreshInterval: newInterval > 0
          ? newInterval
          : currentSettings.resumeRefreshInterval,
      autoOpen: _autoOpen,
      screener: _screenerCtrl.text.trim(),
      showAllJobs: _showAllJobs,
      concurrency: newConcurrency,
      epOpenMode: _epOpenMode,
    );

    await ref.read(settingsProvider.notifier).update(newSettings);
    ref.read(refreshProvider.notifier).restart();

    ref.read(logProvider.notifier).success('配置已保存');
    if (seconds == 0) {
      ref.read(logProvider.notifier).info('刷新已暂停（频率设为0）');
    } else {
      ref.read(logProvider.notifier).info('刷新频率已设为：$seconds秒');
    }
    if (newSettings.screener.isNotEmpty) {
      ref.read(logProvider.notifier).info('初筛人已设置：${newSettings.screener}');
    }
    ref.read(logProvider.notifier).info('并发数：${newSettings.concurrency}');

    _showToast('配置已保存');
  }

  Future<void> _resetStats() async {
    final ok = await _showConfirm('确认重置今日统计（含视频时长）？');
    if (ok != true) return;
    await ref.read(statsProvider.notifier).reset();
    ref.read(logProvider.notifier).warn('今日统计已重置（含视频时长）');
    _showToast('已重置');
  }

  void _clearLogs() {
    ref.read(logProvider.notifier).clear();
    _showToast('日志已清空');
  }

  Future<void> _rescanFailEps() async {
    ref.read(failEpsProvider.notifier).rescan();
    _showToast('开始重新扫描');
  }

  void _showToast(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('确认'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
