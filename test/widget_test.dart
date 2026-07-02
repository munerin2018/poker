// 開始画面が表示されることを確認する、簡単な自動テストです。
// `flutter test` で実行できます。

import 'package:flutter_test/flutter_test.dart';

import 'package:poker/main.dart';

void main() {
  testWidgets('開始画面にタイトルとStartボタンが出る', (WidgetTester tester) async {
    await tester.pumpWidget(const PokerApp());

    expect(find.textContaining('ポーカー'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
  });
}
