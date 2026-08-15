import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/log_provider.dart';
import '../providers/stats_provider.dart';

/// 浏览器通知服务
/// 用于接收油猴脚本发送的标注成功通知
class BrowserNotificationService {
  BrowserNotificationService(this._ref);
  
  final Ref _ref;
  HttpServer? _server;
  bool _isRunning = false;
  
  /// 服务器端口
  static const int port = 18080;
  
  /// 是否正在运行
  bool get isRunning => _isRunning;
  
  /// 启动服务器
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      _isRunning = true;
      
      _ref.read(logProvider.notifier).info('浏览器通知服务已启动 (端口: $port)');
      
      _server!.listen((request) async {
        await _handleRequest(request);
      });
    } catch (e) {
      _ref.read(logProvider.notifier).error('启动通知服务失败: $e');
    }
  }
  
  /// 停止服务器
  Future<void> stop() async {
    if (!_isRunning) return;
    
    await _server?.close();
    _server = null;
    _isRunning = false;
    
    _ref.read(logProvider.notifier).info('浏览器通知服务已停止');
  }
  
  /// 处理请求
  Future<void> _handleRequest(HttpRequest request) async {
    // 设置 CORS 头，允许跨域请求
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    
    // 处理 OPTIONS 预检请求
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }
    
    // 只处理 POST 请求
    if (request.method == 'POST') {
      try {
        // 读取请求体
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        
        // 处理通知
        await _processNotification(data);
        
        // 返回成功响应
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({
          'success': true,
          'message': '通知已接收',
        }));
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({
          'success': false,
          'message': '请求格式错误: $e',
        }));
      }
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write(jsonEncode({
        'success': false,
        'message': '不支持的请求方法',
      }));
    }
    
    await request.response.close();
  }
  
  /// 处理通知
  Future<void> _processNotification(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final episodeId = data['episodeId'] as int?;
    final taskId = data['taskId'] as int?;
    final message = data['message'] as String?;
    
    _ref.read(logProvider.notifier).info('收到浏览器通知: $type');
    
    switch (type) {
      case 'review_success':
        // 标注成功，增加计数
        await _ref.read(statsProvider.notifier).addSuccess(episodeId: episodeId);
        _ref.read(logProvider.notifier).success(
          '浏览器标注成功: EP $episodeId (任务 $taskId)',
        );
        break;
        
      case 'review_failed':
        // 标注失败
        _ref.read(logProvider.notifier).warn(
          '浏览器标注失败: EP $episodeId - $message',
        );
        break;
        
      case 'ping':
        // 心跳检测
        _ref.read(logProvider.notifier).info('浏览器心跳检测');
        break;
        
      default:
        _ref.read(logProvider.notifier).warn('未知通知类型: $type');
    }
  }
}

/// 浏览器通知服务 Provider
final browserNotificationServiceProvider = Provider<BrowserNotificationService>((ref) {
  final service = BrowserNotificationService(ref);
  
  // 自动启动服务
  service.start();
  
  // 释放时停止服务
  ref.onDispose(() {
    service.stop();
  });
  
  return service;
});

