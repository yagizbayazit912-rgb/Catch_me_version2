import 'package:flutter_test/flutter_test.dart';

import 'package:catch_me/main.dart';

void main() {
  testWidgets('Uygulama açılır ve tema örnek ekranı görünür', (tester) async {
    await tester.pumpWidget(const CatchMeApp());
    expect(find.text('Catch Me · Tema'), findsOneWidget);
    expect(find.text('Altın Topla'), findsOneWidget);
  });
}
