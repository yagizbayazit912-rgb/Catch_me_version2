import 'package:catch_me/core/theme/app_theme.dart';
import 'package:catch_me/features/theme_demo/theme_demo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Harita ekranı platform view + GPS gerektirir; cihazda elle test edilir.
  testWidgets('Tema örnek ekranı palet ve bileşenleri gösterir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const ThemeDemoScreen(),
    ));
    expect(find.text('Catch Me · Tema'), findsOneWidget);
    expect(find.text('Altın Topla'), findsOneWidget);
  });
}
