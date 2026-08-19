import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_quote.dart';
import '../data/storage/config_storage.dart';
import 'app_providers.dart';

/// 每日谏言状态。
class DailyQuoteState {
  const DailyQuoteState({
    this.quote,
    this.loading = false,
    this.failed = false,
  });

  final DailyQuote? quote;
  final bool loading;
  final bool failed;
}

/// 每日谏言 Notifier。
///
/// 使用「一言」公开接口（https://v1.hitokoto.cn）获取一句每日语录，
/// 结果按日期缓存到本地（当天只请求一次），次日自动重新拉取。
class DailyQuoteNotifier extends StateNotifier<DailyQuoteState> {
  DailyQuoteNotifier(this._storage) : super(const DailyQuoteState(loading: true));

  final ConfigStorage _storage;

  /// 加载：优先读当天缓存，否则请求接口。
  Future<void> load() async {
    final cached = _storage.loadDailyQuote();
    if (cached != null) {
      state = DailyQuoteState(quote: cached);
      return;
    }
    await refresh();
  }

  /// 强制刷新一句（用户点击「换一句」）。
  Future<void> refresh() async {
    state = DailyQuoteState(loading: true, quote: state.quote);
    try {
      final quote = await _fetchQuote();
      await _storage.saveDailyQuote(quote);
      state = DailyQuoteState(quote: quote);
    } catch (_) {
      // 失败时回退到本地兜底谏言，避免空白。
      state = DailyQuoteState(
        quote: state.quote ?? _fallbackQuote(),
        failed: state.quote == null,
      );
    }
  }

  Future<DailyQuote> _fetchQuote() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        responseType: ResponseType.json,
      ),
    );
    // 偏文学 / 诗词 / 哲学，更贴合「谏言」语义。
    final res = await dio.get('https://v1.hitokoto.cn/?c=d&c=i&c=k');
    final data = res.data;
    if (data is Map) {
      final quote = DailyQuote.fromHitokoto(Map<String, dynamic>.from(data));
      if (quote.content.isNotEmpty) return quote;
    }
    throw const FormatException('无效的谏言接口响应');
  }

  DailyQuote _fallbackQuote() {
    return const DailyQuote(
      content: '路漫漫其修远兮，吾将上下而求索。',
      from: '离骚',
      fromWho: '屈原',
    );
  }
}

/// 每日谏言 provider。
final dailyQuoteProvider =
    StateNotifierProvider<DailyQuoteNotifier, DailyQuoteState>((ref) {
  final storage = ref.watch(configStorageProvider);
  final notifier = DailyQuoteNotifier(storage);
  Future.microtask(() => notifier.load());
  return notifier;
});
