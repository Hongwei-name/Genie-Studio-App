import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/tasks_provider.dart';

/// 应用内 WebView 页面
/// 1. 先导航到 baseURL 设置 Cookie，再跳转 EP URL（解决首次请求不带 Cookie 问题）
/// 2. 注入 MutationObserver 监听"标注成功"消息，通过 webMessage 回传 Dart
class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({
    super.key,
    required this.url,
    required this.cookie,
    required this.episodeId,
  });

  final String url;
  final String cookie;
  final int episodeId;

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage> {
  final _controller = WebviewController();
  bool _initialized = false;
  String? _error;
  bool _canGoBack = false;
  bool _cookieReady = false;
  StreamSubscription? _historySub;
  StreamSubscription? _urlSub;
  StreamSubscription? _msgSub;
  Timer? _statsPollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();

      _historySub = _controller.historyChanged.listen((h) {
        if (mounted) setState(() => _canGoBack = h.canGoBack);
      });

      // 监听 webMessage（JS → Dart）
      _msgSub = _controller.webMessage.listen(_onWebMessage);

      // 注入 Cookie 设置脚本 + 标注成功监听脚本（每次新文档加载前执行）
      await _controller.addScriptToExecuteOnDocumentCreated(
        _buildInitScript(),
      );

      if (mounted) setState(() => _initialized = true);

      // 策略：先导航到 baseURL 设置 Cookie，再跳转目标 URL
      if (widget.cookie.isNotEmpty) {
        await _controller.loadUrl(AppConfig.webViewLoginUrl);
        // 等待页面加载后 Cookie 即被注入到 document.cookie
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() => _cookieReady = true);
        await _controller.loadUrl(widget.url);
      } else {
        setState(() => _cookieReady = true);
        await _controller.loadUrl(widget.url);
      }

      // 启动轮询检测"标注成功"（兜底机制，MutationObserver 可能漏消息）
      _startStatsPoll();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// 构建注入脚本：设置 Cookie + MutationObserver 监听标注成功
  String _buildInitScript() {
    final sb = StringBuffer();

    // 1. 注入 Cookie
    if (widget.cookie.isNotEmpty) {
      final cookies = widget.cookie.split(';');
      for (final c in cookies) {
        final trimmed = c.trim();
        if (trimmed.isEmpty) continue;
        // 过滤掉属性字段（Path=, Domain=, HttpOnly 等）
        if (trimmed.toLowerCase().contains('path=') ||
            trimmed.toLowerCase().contains('domain=') ||
            trimmed.toLowerCase().contains('httponly') ||
            trimmed.toLowerCase().contains('secure') ||
            trimmed.toLowerCase().contains('samesite=')) {
          continue;
        }
        // 转义单引号
        final escaped = trimmed.replaceAll("'", "\\'");
        sb.write("try{document.cookie='$escaped; path=/; domain=.agibot.com';}catch(e){}");
      }
    }

    // 2. MutationObserver 监听"标注成功"消息
    sb.write('''
      (function(){
        if(window.__agibotMonitor) return;
        window.__agibotMonitor = true;
        var observer = new MutationObserver(function(mutations){
          for(var mi=0; mi<mutations.length; mi++){
            var nodes = mutations[mi].addedNodes;
            for(var ni=0; ni<nodes.length; ni++){
              var node = nodes[ni];
              if(node.nodeType !== 1) continue;
              var msgEl = node.matches('.el-message,.el-message-box') ? node : node.querySelector('.el-message,.el-message-box');
              if(!msgEl || msgEl.dataset.agibotMarked) continue;
              if(msgEl.textContent.indexOf('标注成功') !== -1){
                msgEl.dataset.agibotMarked = '1';
                try{ window.chrome.webview.postMessage(JSON.stringify({type:'reviewSuccess'})); }catch(e){}
              }
            }
          }
        });
        observer.observe(document.body || document.documentElement, {childList:true, subtree:true});
      })();
    ''');

    return sb.toString();
  }

  void _onWebMessage(dynamic message) {
    try {
      final msg = message is String ? jsonDecode(message) : message;
      if (msg is Map && msg['type'] == 'reviewSuccess') {
        ref.read(tasksProvider.notifier).onEpisodeReviewed(widget.episodeId);
      }
    } catch (_) {}
  }

  /// 轮询检测标注成功（兜底：MutationObserver 在某些 SPA 场景可能漏消息）
  void _startStatsPoll() {
    _statsPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_initialized) return;
      try {
        final result = await _controller.executeScript('''
          (function(){
            var msgs = document.querySelectorAll('.el-message,.el-message-box');
            for(var i=0;i<msgs.length;i++){
              if(!msgs[i].dataset.agibotPolled && msgs[i].textContent.indexOf('标注成功')!==-1){
                msgs[i].dataset.agibotPolled = '1';
                return 'success';
              }
            }
            return '';
          })()
        ''');
        if (result == 'success') {
          ref.read(tasksProvider.notifier).onEpisodeReviewed(widget.episodeId);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    _historySub?.cancel();
    _urlSub?.cancel();
    _msgSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.windowBackground,
      appBar: AppBar(
        title: const Text('EP审核'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
        actions: _initialized
            ? [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: _canGoBack ? () => _controller.goBack() : null,
                  tooltip: '后退',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => _controller.reload(),
                  tooltip: '刷新',
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    if (!_initialized || !_cookieReady) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text('正在加载并注入 Cookie...',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          ],
        ),
      );
    }
    return Webview(_controller);
  }

  Widget _buildError() {
    final isRuntimeMissing =
        _error?.contains('WebView2') == true || _error?.contains('runtime') == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber,
                size: 48, color: AppTheme.warning),
            const SizedBox(height: 12),
            Text(
              isRuntimeMissing ? 'WebView2 运行时未安装' : 'WebView 初始化失败',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRuntimeMissing
                  ? '请安装 Microsoft Edge WebView2 Runtime\n或将"EP打开方式"切换为"浏览器"'
                  : _error ?? '',
              style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
