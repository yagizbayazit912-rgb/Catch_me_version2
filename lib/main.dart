import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/map/map_screen.dart';

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
      home: const MapScreen(),
    );
  }
}
