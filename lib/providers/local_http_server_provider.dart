import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log_provider.dart';
import 'tasks_provider.dart';

/// 本地HTTP服务，用于接收浏览器脚本的通知
class LocalHttpServer {
  HttpServer? _server;
  final Ref _ref;
  static const int _port = 19080;

  LocalHttpServer(this._ref);

  /// 启动HTTP服务
  Future<void> start() async {
    if (_server != null) return;
    
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      print('[LocalHttpServer] 服务已启动，端口: $_port');
      
      _server!.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/review-success') {
          try {
            final body = await request.fold<List<int>>([], (prev, element) => prev..addAll(element));
            final jsonStr = utf8.decode(body);
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final episodeId = data['episodeId'] as int?;
            
            if (episodeId != null) {
              print('[LocalHttpServer] 收到审核成功通知: EP=$episodeId');
              _ref.read(tasksProvider.notifier).onEpisodeReviewed(episodeId);
            }
            
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': true}))
              ..close();
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write(jsonEncode({'error': '$e'}))
              ..close();
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      print('[LocalHttpServer] 启动失败: $e');
    }
  }

  /// 停止HTTP服务
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// 服务是否运行中
  bool get isRunning => _server != null;
}

/// 本地HTTP服务 provider
final localHttpServerProvider = Provider<LocalHttpServer>((ref) {
  final server = LocalHttpServer(ref);
  ref.onDispose(() => server.stop());
  return server;
});
