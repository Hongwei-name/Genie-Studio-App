import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 系统托盘管理
class AppTrayManager with TrayListener {
  static final AppTrayManager _instance = AppTrayManager._();
  factory AppTrayManager() => _instance;
  AppTrayManager._();

  bool _initialized = false;

  /// 初始化系统托盘
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    trayManager.addListener(this);

    // 获取图标路径
    final iconPath = _getIconPath();

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('zero_K-Genie');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: '显示主窗口'),
          MenuItem(key: 'separator', type: 'separator'),
          MenuItem(key: 'exit_app', label: '退出程序'),
        ],
      ),
    );
  }

  String _getIconPath() {
    // Windows 图标路径
    final exePath = Platform.resolvedExecutable;
    final dir = exePath.substring(0, exePath.lastIndexOf('\\'));
    return '$dir\\data\\flutter_assets\\assets\\tray_icon.ico';
  }

  @override
  void onTrayIconMouseDown() {
    // 单击托盘图标显示窗口
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // 右键显示菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _showWindow();
        break;
      case 'exit_app':
        _exitApp();
        break;
    }
  }

  /// 显示窗口
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 退出应用
  Future<void> _exitApp() async {
    await trayManager.destroy();
    exit(0);
  }

  /// 最小化到托盘
  Future<void> minimizeToTray() async {
    await windowManager.hide();
  }

  /// 销毁托盘
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
