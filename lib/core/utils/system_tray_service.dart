import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘服务
class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;

  /// 初始化系统托盘
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 初始化系统托盘
      await _systemTray.initSystemTray(
        title: 'zero_K-Genie',
        iconPath: 'windows/runner/resources/app_icon.ico',
      );

      // 创建右键菜单
      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示主窗口',
          onClicked: (menuItem) async {
            await showWindow();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '完全退出程序',
          onClicked: (menuItem) async {
            await exitApp();
          },
        ),
      ]);

      // 设置右键菜单
      await _systemTray.setContextMenu(menu);

      // 点击托盘图标显示窗口
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
      debugPrint('✅ 系统托盘初始化成功');
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

  /// 完全退出应用
  Future<void> exitApp() async {
    _isInitialized = false;
    await _systemTray.destroy();
    await windowManager.destroy();
    exit(0);
  }

  /// 销毁托盘
  Future<void> destroy() async {
    if (_isInitialized) {
      await _systemTray.destroy();
      _isInitialized = false;
    }
  }
}
