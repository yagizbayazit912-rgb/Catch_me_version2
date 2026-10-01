/// Derleme zamanı gizli ayarlar. Değerler repoya girmeyen `.env`
/// dosyasından gelir: `flutter run --dart-define-from-file=.env`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Google Cloud'daki **Web** OAuth istemci kimliği (Android olan değil).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
