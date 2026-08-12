import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/format_utils.dart';

/// 配置存储
/// 对齐原脚本 Store（基于 GM_getValue/GM_setValue）
/// 使用 SharedPreferences 持久化
class ConfigStorage {
  ConfigStorage._(this._prefs);

  final SharedPreferences _prefs;

  static const _kSettings = 'app_settings';
  static const _kStats = 'ep_complete_stat';
  static const _kFrames = 'ep_total_frames';
  static const _kOpenedEps = 'opened_eps';

  static Future<ConfigStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ConfigStorage._(prefs);
  }

  // ========== 应用配置 ==========

  /// 读取应用配置
  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// 保存应用配置
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  // ========== 今日统计 ==========

  /// 获取今日完成数
  int todayCompleteCount() {
    final map = _loadMap(_kStats);
    return map[FormatUtils.todayString()] ?? 0;
  }

  /// 获取今日总帧数
  int todayFrames() {
    final map = _loadMap(_kFrames);
    return map[FormatUtils.todayString()] ?? 0;
  }

  /// 增加今日完成数
  Future<void> incrementTodayCount() async {
    final map = _loadMap(_kStats);
    final today = FormatUtils.todayString();
    map[today] = (map[today] ?? 0) + 1;
    await _saveMap(_kStats, map);
  }

  /// 增加今日帧数
  Future<void> addTodayFrames(int frames) async {
    if (frames <= 0) return;
    final map = _loadMap(_kFrames);
    final today = FormatUtils.todayString();
    map[today] = (map[today] ?? 0) + frames;
    await _saveMap(_kFrames, map);
  }

  /// 重置今日统计（含帧数）
  Future<void> resetTodayStats() async {
    final statsMap = _loadMap(_kStats);
    final framesMap = _loadMap(_kFrames);
    final today = FormatUtils.todayString();
    statsMap[today] = 0;
    framesMap[today] = 0;
    await _saveMap(_kStats, statsMap);
    await _saveMap(_kFrames, framesMap);
  }

  // ========== 已打开 EP 记录 ==========

  /// 标记 EP 已打开
  Future<void> markEpOpened(String epKey) async {
    final map = _loadMap(_kOpenedEps);
    map[epKey] = DateTime.now().millisecondsSinceEpoch;
    // 超出上限时删除最早的
    if (map.length > AppConfig.maxOpenedEps) {
      final sorted = map.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final toRemove = sorted.take(map.length - AppConfig.maxOpenedEps);
      for (final entry in toRemove) {
        map.remove(entry.key);
      }
    }
    await _saveMap(_kOpenedEps, map);
  }

  /// 检查 EP 今日是否已打开
  bool isEpOpenedToday(String epKey) {
    final map = _loadMap(_kOpenedEps);
    final ts = map[epKey];
    if (ts == null) return false;
    final today = FormatUtils.todayString();
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return date.toIso8601String().substring(0, 10) == today;
  }

  /// 清理非今日的已打开 EP 记录
  Future<void> cleanOldOpenedEps() async {
    final map = _loadMap(_kOpenedEps);
    final today = FormatUtils.todayString();
    var changed = false;
    final keysToRemove = <String>[];
    for (final entry in map.entries) {
      final date = DateTime.fromMillisecondsSinceEpoch(entry.value);
      if (date.toIso8601String().substring(0, 10) != today) {
        keysToRemove.add(entry.key);
        changed = true;
      }
    }
    for (final key in keysToRemove) {
      map.remove(key);
    }
    if (changed) await _saveMap(_kOpenedEps, map);
  }

  // ========== 内部工具 ==========

  Map<String, int> _loadMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return <String, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveMap(String key, Map<String, int> map) async {
    await _prefs.setString(key, jsonEncode(map));
  }
}
