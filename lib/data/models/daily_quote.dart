/// 每日谏言数据模型。
class DailyQuote {
  const DailyQuote({
    required this.content,
    this.from = '',
    this.fromWho = '',
  });

  /// 谏言正文。
  final String content;

  /// 出处（书名 / 作品 / 网站等）。
  final String from;

  /// 作者。
  final String fromWho;

  /// 来源标签，例如 "离骚 · 屈原"。
  String get sourceLabel {
    final parts = [from, fromWho].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(' · ');
  }

  /// 从 hitokoto（一言）接口解析。
  factory DailyQuote.fromHitokoto(Map<String, dynamic> json) {
    return DailyQuote(
      content: (json['hitokoto'] as String?)?.trim() ?? '',
      from: (json['from'] as String?)?.trim() ?? '',
      fromWho: (json['from_who'] as String?)?.trim() ?? '',
    );
  }

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      content: (json['content'] as String?) ?? '',
      from: (json['from'] as String?) ?? '',
      fromWho: (json['fromWho'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'from': from,
      'fromWho': fromWho,
    };
  }
}
