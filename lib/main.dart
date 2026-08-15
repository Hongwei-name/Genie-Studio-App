import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/network/api_client.dart';
import 'core/network/browser_notification_service.dart';
import 'data/storage/config_storage.dart';
import 'providers/app_providers.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 隐藏原生 Windows 标题栏，使用自绘 macOS 风格标题栏
  windowManager.setAsFrameless();
  // 开启窗口透明，让圆角裁切后不露出底层黑色画布
  windowManager.setBackgroundColor(Colors.transparent);
  windowManager.setTitle('zero_K-Genie');
  windowManager.setMinimumSize(const Size(800, 500));

  // 设置窗口关闭时最小化而不是退出
  await windowManager.setPreventClose(true);

  // 初始化配置存储
  final storage = await ConfigStorage.create();

  // 清理非今日的已打开 EP 记录（对齐原脚本 Store.cleanOldEps）
  await storage.cleanOldOpenedEps();

  // 预加载配置并同步到 ApiClient
  final settings = storage.loadSettings();
  ApiClient.instance.init(cookie: settings.cookie);

  runApp(
    ProviderScope(
      overrides: [
        configStorageProvider.overrideWithValue(storage),
      ],
      child: const ZeroKGenieApp(),
    ),
  );
}
