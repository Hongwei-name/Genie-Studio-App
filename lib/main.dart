import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'data/storage/config_storage.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  windowManager.setAsFrameless();
  windowManager.setBackgroundColor(Colors.transparent);
  windowManager.setTitle('zero_K-Genie');
  windowManager.setMinimumSize(const Size(800, 500));
  await windowManager.setPreventClose(true);

  final storage = await ConfigStorage.create();
  await storage.cleanOldOpenedEps();

  final settings = storage.loadSettings();
  ApiClient.instance.init(cookie: settings.cookie);

  runApp(
    ProviderScope(
      overrides: [configStorageProvider.overrideWithValue(storage)],
      child: const ZeroKGenieApp(),
    ),
  );
}
