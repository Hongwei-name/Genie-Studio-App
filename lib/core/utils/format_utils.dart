import '../config/app_config.dart';

/// 时间格式化工具
/// 对齐原脚本 formatTime / formatTimeShort
class FormatUtils {
  FormatUtils._();

  /// 将帧数转为可读时长
  /// [frames] 帧数
  /// [short] 是否短格式
  static String formatTime(int frames, {bool short = false}) {
    final totalSeconds = frames ~/ AppConfig.framesPerSecond;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (short) {
      if (h > 0) return '${h}h${m}m';
      if (m > 0) return '${m}m${s}s';
      return '${s}s';
    }
    if (h > 0) return '$h小时$m分$s秒';
    if (m > 0) return '$m分$s秒';
    return '$s秒';
  }

  /// 短格式时长
  static String formatTimeShort(int frames) =>
      formatTime(frames, short: true);

  /// 格式化时间戳为 HH:mm:ss
  static String formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 获取今日日期字符串（YYYY-MM-DD）
  static String todayString() => DateTime.now().toIso8601String().substring(0, 10);

  /// 转义 HTML 特殊字符（保留以对齐原脚本 safeEncode）
  static String safeEncode(String? input) {
    if (input == null) return '';
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }
}
