/// Oyun ayarları. Sayılar koda gömülmez, buradan okunur
/// (ileride sunucudan gelen config ile değiştirilecek).
abstract final class GameConfig {
  /// H3 çözünürlüğü (PROJE_PLANI bölüm 4: Res 9 ≈ 174 m kenar).
  static const h3Resolution = 9;

  /// Kullanıcının hücresi etrafında çizilecek halka sayısı (2 → 19 altıgen).
  static const hexRingSize = 2;

  /// Adım 0.5 (3D deneme): kamera eğimi (derece, plan 45–55°).
  static const mapTilt = 50.0;

  /// Yükseltilmiş altıgenin yüksekliği (metre).
  static const hexExtrusionHeight = 40.0;

  /// Adım 1.4: tek seferde sorulacak en fazla görünür hücre (sunucudaki
  /// `max_visible_hexes` ile aynı). Fazlaysa (çok uzak zoom) sahiplik çizilmez.
  static const maxVisibleHexes = 600;

  /// Görünür alan bu oranda genişletilir (kenardaki hücreler kaçmasın).
  static const visibleBoundsPadding = 0.15;

  /// Sahiplik önbelleğinin tazelik süresi (sn); sonra yeniden sorulur.
  static const ownedCacheTtlSec = 60;

  /// Yükselme animasyonu süresi (ms).
  static const hexRiseMs = 1600;

  /// Adım 1.3: claim kutlaması toplam süresi (ms) ve ripple halka sayısı.
  static const claimCelebrationMs = 1400;
  static const claimRippleRings = 2;

  /// Parıltı sayısı; düşük donanım yedek modunda azı kullanılır.
  static const claimSparkles = 14;
  static const claimSparklesLite = 5;

  /// Ayarlar ekranı gelene kadar sabit: ses / titreşim açık mı.
  static const hapticsEnabled = true;
  static const soundEnabled = true;

  /// Claim sesi (assets/ altında yol, `audio/` ile başlar) ve titreşim.
  static const claimSoundAsset = 'audio/claim.wav';
  static const claimVibrateMs = 80;
  static const claimVibrateAmplitude = 160; // 1–255
}
