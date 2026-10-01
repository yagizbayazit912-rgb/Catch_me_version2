import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

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

  static bool _googleReady = false;

  /// Yerel Google girişi → ID token'ı Supabase doğrular, oturumu o açar.
  /// Kullanıcı pencereyi kapatırsa `false` döner.
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: Env.googleWebClientId);
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Google kimlik bilgisi alınamadı.');
      }
      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthException('Google girişi başarısız (${e.code.name}).');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }
}
