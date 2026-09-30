import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/theme_demo/theme_demo_screen.dart';

void main() {
  runApp(const CatchMeApp());
}

class CatchMeApp extends StatelessWidget {
  const CatchMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch Me',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Adım 0.2: geçici olarak tema örnek ekranı; harita ekranı 0.1'den kalır.
      home: const ThemeDemoScreen(),
    );
  }
}
