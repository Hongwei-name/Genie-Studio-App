import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// Owns the Windows tray icon and the window's hide/exit behavior.
class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _isInitialized = false;
  bool _isExiting = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final iconPath = await _writeTrayIcon();
      await _systemTray.initSystemTray(
        title: 'zero_K-Genie',
        iconPath: iconPath,
        toolTip: 'zero_K-Genie 智元标注审核助手',
      );
      await _menu.buildFrom([
        MenuItemLabel(label: '显示窗口', onClicked: (_) => showWindow()),
        MenuSeparator(),
        MenuItemLabel(label: '退出应用', onClicked: (_) => exitApp()),
      ]);
      await _systemTray.setContextMenu(_menu);
      _systemTray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == kSystemTrayEventDoubleClick) {
          await showWindow();
        } else if (eventName == kSystemTrayEventClick) {
          await _systemTray.popUpContextMenu();
        }
      });
      _isInitialized = true;
      debugPrint('System tray initialized.');
    } catch (error) {
      _isInitialized = false;
      debugPrint('System tray initialization failed: $error');
    }
  }

  Future<String> _writeTrayIcon() async {
    final data = await rootBundle.load('windows/runner/resources/app_icon.ico');
    final iconFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}zero_k_genie_tray.ico',
    );
    await iconFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return iconFile.path;
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() => windowManager.hide();

  Future<void> exitApp() async {
    if (_isExiting) return;
    _isExiting = true;
    _isInitialized = false;
    await _systemTray.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  Future<void> destroy() async {
    _isInitialized = false;
    await _systemTray.destroy();
  }
}
