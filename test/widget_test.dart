import 'package:flutter_test/flutter_test.dart';

import 'package:genie_review_assistant/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 验证应用根 Widget 可被构造
    expect(const GenieReviewApp(), isNotNull);
  });
}
