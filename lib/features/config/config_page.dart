import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/fail_eps_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/stats_provider.dart';
import '../../data/models/app_settings.dart';

/// 配置页
/// 包含 Token（Cookie）配置、刷新、自动打开、并发数、EP打开方式等
class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  late TextEditingController _cookieCtrl;
  late TextEditingController _refreshCtrl;
  late TextEditingController _screenerCtrl;
  late int _concurrency;
  late EpOpenMode _epOpenMode;
  late bool _autoOpen;
  late bool _showAllJobs;
  bool _obscureCookie = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _cookieCtrl = TextEditingController(text: s.cookie);
    _refreshCtrl = TextEditingController(
      text: '${s.refreshIntervalSeconds}',
    );
    _screenerCtrl = TextEditingController(text: s.screener);
    _concurrency = s.concurrency;
    _epOpenMode = s.epOpenMode;
    _autoOpen = s.autoOpen;
    _showAllJobs = s.showAllJobs;
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    _refreshCtrl.dispose();
    _screenerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
            _buildSection(
              title: '认证',
              children: [
                _buildCookieRow(),
              ],
            ),
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
            _buildSection(
              title: '并发与性能',
              children: [
                _buildConcurrencyRow(),
              ],
            ),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                onTap: () =>
                    setState(() => _obscureCookie = !_obscureCookie),
                child: Icon(
                  _obscureCookie
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 16,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '从浏览器开发者工具复制完整 Cookie 字符串。用于桌面端直接调用 API，无需浏览器登录。',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cookieCtrl,
            obscureText: _obscureCookie,
            maxLines: _obscureCookie ? 1 : 3,
            minLines: 1,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '例如：session=xxx; token=yyy',
              hintStyle:
                  const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.windowBackground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: const BorderSide(color: AppTheme.separator),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: const BorderSide(color: AppTheme.separator),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '刷新频率',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '任务列表自动刷新间隔（秒，0=暂停）',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _refreshCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: AppTheme.windowBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.separator),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '秒',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildConcurrencyRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '并发数',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '$_concurrency',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '控制任务/Job/EP 并发请求数（1-64）。桌面端核心提升项。',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '1',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
              Expanded(
                child: Slider(
                  value: _concurrency.toDouble(),
                  min: AppConfig.minConcurrency.toDouble(),
                  max: AppConfig.maxConcurrency.toDouble(),
                  divisions: AppConfig.maxConcurrency - 1,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _concurrency = v.toInt()),
                ),
              ),
              const Text(
                '64',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '初筛人',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '只显示该初筛人处理的验收失败EP（用户名，如 zhoujun）',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _screenerCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '留空=全部',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: AppTheme.windowBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.separator),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpOpenModeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'EP 打开方式',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '点击 EP 按钮后，用系统浏览器或应用内 WebView 打开审核页',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          SegmentedButton<EpOpenMode>(
            segments: const [
              ButtonSegment(
                  value: EpOpenMode.browser, label: Text('浏览器')),
              ButtonSegment(
                  value: EpOpenMode.webview, label: Text('WebView')),
            ],
            selected: {_epOpenMode},
            onSelectionChanged: (v) {
              if (v.isNotEmpty) setState(() => _epOpenMode = v.first);
            },
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
                      fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppTheme.primary,
            onChanged: onChanged,
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
                      fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDestructive ? AppTheme.danger : AppTheme.primary,
              backgroundColor: isDestructive
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : AppTheme.surfaceHover,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 操作 ==========

  Future<void> _togglePause(bool paused) async {
    final cur = ref.read(settingsProvider);
    final newInterval = paused ? 0 : AppConfig.defaultRefreshInterval;
    await ref.read(settingsProvider.notifier).update(
          cur.copyWith(refreshInterval: newInterval),
        );
    ref.read(refreshProvider.notifier).restart();
    ref.read(logProvider.notifier).info(paused ? '已暂停刷新' : '已恢复刷新');
  }

  Future<void> _save() async {
    // 解析刷新频率
    var seconds = int.tryParse(_refreshCtrl.text.trim()) ?? 0;
    if (seconds < 0) seconds = 0;
    if (seconds > 600) seconds = 600;
    final newInterval = seconds * 1000;

    final newSettings = AppSettings(
      cookie: _cookieCtrl.text.trim(),
      refreshInterval: newInterval,
      autoOpen: _autoOpen,
      screener: _screenerCtrl.text.trim(),
      showAllJobs: _showAllJobs,
      concurrency: _concurrency,
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
