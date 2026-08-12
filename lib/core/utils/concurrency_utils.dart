import 'dart:async';

/// 并发池工具
/// 对齐原脚本 runConcurrent，但支持可配置并发数
/// 解决原脚本并发能力不足的问题
class ConcurrencyUtils {
  ConcurrencyUtils._();

  /// 并发执行任务列表
  /// [items] 待处理项
  /// [fn] 单项处理函数（返回 `Future<R>`）
  /// [limit] 最大并发数
  /// 返回与 items 等长、按原顺序对齐的结果列表（失败项为 null）
  static Future<List<R?>> runConcurrent<T, R>(
    List<T> items,
    Future<R> Function(T item, int index) fn,
    int limit,
  ) {
    final List<R?> results = List<R?>.filled(items.length, null);
    final completer = Completer<List<R?>>();

    if (items.isEmpty) {
      completer.complete(results);
      return completer.future;
    }

    final effectiveLimit = limit.clamp(1, items.length);
    int index = 0;
    int active = 0;
    int completed = 0;
    final total = items.length;

    void scheduleNext() {
      while (active < effectiveLimit && index < total) {
        final currentIdx = index;
        final item = items[currentIdx];
        index++;
        active++;

        fn(item, currentIdx).then((result) {
          results[currentIdx] = result;
        }).catchError((Object err) {
          // 单项失败不影响整体，记录 null
          results[currentIdx] = null;
        }).whenComplete(() {
          active--;
          completed++;
          if (completed >= total) {
            if (!completer.isCompleted) completer.complete(results);
          } else {
            scheduleNext();
          }
        });
      }
    }

    scheduleNext();
    return completer.future;
  }
}
