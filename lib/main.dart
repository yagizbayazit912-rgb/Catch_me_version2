import 'package:flutter/material.dart';

import 'features/map/map_screen.dart';

void main() {
  runApp(const CatchMeApp());
}

class CatchMeApp extends StatelessWidget {
  const CatchMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Catch Me',
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}
