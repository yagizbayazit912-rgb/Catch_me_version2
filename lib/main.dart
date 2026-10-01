import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }
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
      home: Env.isConfigured ? const AuthGate() : const _MissingEnvScreen(),
    );
  }
}

/// `.env` verilmeden çalıştırılırsa çökmek yerine ne yapılacağını söyler.
class _MissingEnvScreen extends StatelessWidget {
  const _MissingEnvScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase ayarı bulunamadı.\n'
            '.env dosyasını oluşturup şununla çalıştır:\n'
            'flutter run --dart-define-from-file=.env',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
