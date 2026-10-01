import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth_repository.dart';

/// E-posta + şifre ile giriş / kayıt.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repo});

  final AuthRepository repo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Sunucudaki `users.username` kontrolüyle aynı kural.
  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      if (_isSignUp) {
        final signedIn = await widget.repo.signUp(
          email: _email.text.trim(),
          password: _password.text,
          username: _username.text.trim(),
        );
        if (!signedIn) {
          message = 'Kayıt tamam! E-postandaki onay bağlantısına tıkla.';
        }
      } else {
        await widget.repo.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Bağlantı kurulamadı. İnternetini kontrol et.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  void _toggleMode() => setState(() {
    _isSignUp = !_isSignUp;
    _message = null;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                boxShadow: AppTheme.softShadow,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Catch Me',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? 'Yeni hesap aç' : 'Tekrar hoş geldin!',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı adı',
                        ),
                        validator: (v) =>
                            _usernamePattern.hasMatch(v?.trim() ?? '')
                            ? null
                            : '3–20 harf, rakam ya da _',
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (v) => (v?.contains('@') ?? false)
                          ? null
                          : 'Geçerli bir e-posta yaz',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      validator: (v) =>
                          (v?.length ?? 0) >= 6 ? null : 'En az 6 karakter',
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(_isSignUp ? 'Kayıt ol' : 'Giriş yap'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(
                        _isSignUp
                            ? 'Zaten hesabım var'
                            : 'Hesabın yok mu? Kayıt ol',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
