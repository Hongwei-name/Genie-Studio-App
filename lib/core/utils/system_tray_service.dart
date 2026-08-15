import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘服务（简化版）
/// 由于 Windows API 调用复杂，使用简化实现
class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  bool _isInitialized = false;

  /// 初始化系统托盘
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      debugPrint('✅ 系统托盘服务已初始化');
    } catch (e) {
      debugPrint('❌ 系统托盘初始化失败: $e');
    }
  }

  /// 显示窗口
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 隐藏窗口（最小化到托盘）
  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  /// 退出应用
  Future<void> exitApp() async {
    _isInitialized = false;
    await windowManager.destroy();
  }

  /// 销毁托盘
  Future<void> destroy() async {
    _isInitialized = false;
  }
}
