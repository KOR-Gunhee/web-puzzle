import 'package:flutter_test/flutter_test.dart';

import 'package:web_puzzle/main.dart';

void main() {
  testWidgets('shows the empty-state prompt before a photo is picked',
      (tester) async {
    await tester.pumpWidget(const PuzzleApp());
    expect(find.text('사진을 불러와 퍼즐을 시작해보세요'), findsOneWidget);
  });
}
