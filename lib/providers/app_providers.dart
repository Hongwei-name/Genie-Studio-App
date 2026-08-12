import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/review_repository.dart';
import '../data/storage/config_storage.dart';

/// 配置存储 provider
/// 在 main() 中通过 override 注入已初始化的实例
final configStorageProvider = Provider<ConfigStorage>((ref) {
  throw UnimplementedError('configStorageProvider must be overridden in main()');
});

/// 应用配置 Notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(const AppSettings());

  final ConfigStorage _storage;

  /// 从存储加载
  Future<void> load() async {
    state = _storage.loadSettings();
    // 同步 Cookie 到 ApiClient
    ApiClient.instance.init(cookie: state.cookie);
  }

  /// 更新配置并持久化
  Future<void> update(AppSettings settings) async {
    state = settings;
    await _storage.saveSettings(settings);
    // Cookie 变更同步到 ApiClient
    if (settings.cookie != ApiClient.instance.cookie) {
      ApiClient.instance.updateCookie(settings.cookie);
    }
  }

  /// 更新 Cookie
  Future<void> updateCookie(String cookie) async {
    await update(state.copyWith(cookie: cookie));
  }
}

/// 应用配置 provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(configStorageProvider);
  final notifier = SettingsNotifier(storage);
  // 初始化时加载配置并同步到 ApiClient
  Future.microtask(() async {
    await notifier.load();
  });
  return notifier;
});

/// Repository provider
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

/// 当前选中的任务 ID（用于侧边栏二级菜单 → 内容区通信）
final selectedTaskIdProvider = StateProvider<int?>((ref) => null);
