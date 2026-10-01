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

  /// Yükselme animasyonu süresi (ms).
  static const hexRiseMs = 900;
}
