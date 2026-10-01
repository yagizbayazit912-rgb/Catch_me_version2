import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../map/map_screen.dart';
import 'login_screen.dart';

/// Oturum varsa haritayı, yoksa giriş ekranını gösterir.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _repo.authStateChanges,
      builder: (context, _) => _repo.currentSession == null
          ? LoginScreen(repo: _repo)
          : MapScreen(onSignOut: _repo.signOut),
    );
  }
}
