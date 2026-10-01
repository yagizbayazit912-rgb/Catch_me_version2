import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth sarmalayıcısı. Karar/doğrulama sunucuda; burası sadece ister.
class AuthRepository {
  AuthRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Kayıt; `username` sunucudaki tetikleyiciye meta veri olarak gider.
  /// Dönen değer: oturum açıldı mı (e-posta onayı açıksa `false`).
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    return res.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();
}
