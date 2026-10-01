/// Derleme zamanı gizli ayarlar. Değerler repoya girmeyen `.env`
/// dosyasından gelir: `flutter run --dart-define-from-file=.env`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
