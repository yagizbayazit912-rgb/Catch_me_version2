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

  /// Adım 1.6: yürüyüş modu. Ping aralığı (sn), konum filtresi (m),
  /// otomatik duraklama hızı (25 km/s) ve geçiş için ardışık okuma sayısı.
  static const walkPingIntervalSec = 15;
  static const walkDistanceFilterM = 0;
  static const walkMaxSpeedMps = 25 / 3.6;
  static const walkSpeedStreak = 2;

  /// GPS iyileştirme: konum bu sıklıkla (sn) okunur, ping penceresindeki en
  /// iyi (en düşük doğruluk yarıçaplı) okuma gönderilir. Bu yarıçapın (m)
  /// üstündeki okumalar hiç gönderilmez; sunucudaki `ping_soft_max_accuracy_m`
  /// ile aynı tutulmalı (karar yine sunucuda).
  static const walkFixIntervalSec = 3;
  static const walkMaxSendAccuracyM = 100.0;

  /// Bundan eski okuma gönderilmez (sunucu `ping_max_age_s` daha geniş).
  static const walkMaxFixAgeSec = 30;
  static const walkNotificationTitle = 'Catch Me aktif';
  static const walkNotificationText = 'Yürüyüşün takip ediliyor';

  /// Adım 2.2: çadır. Fiyat sunucudaki `build_cost_1` ile aynı (sadece
  /// gösterim; kararı sunucu verir).
  static const tentCost = 100;

  /// Çadır ölçüleri hücre yarıçapına oranla (her hücreye aynı oranda oturur,
  /// zoom'la birlikte ölçeklenir): yarım genişlik, yarım boy, yükseklik.
  static const tentHalfWidth = 0.24;
  static const tentHalfLength = 0.30;
  static const tentHeight = 0.30;

  /// Çatı basamak sayısı (çok = pürüzsüz, az = oyuncak blok); çizgili kumaş
  /// her basamakta renk değiştirir.
  static const tentSlices = 14;

  /// Çan profili üssü (1 = düz A, büyük = taban geniş tepe sivri) ve ön/arka
  /// yüzün yukarı doğru içe eğimi (yarım boy oranı).
  static const tentBellExp = 1.3;
  static const tentGableLean = 0.12;

  /// Kapı: yüksekliği (çadır yüksekliğine oran) ve basamak sayısı.
  static const tentDoorHeight = 0.55;
  static const tentDoorSlices = 6;

  /// Flama parça sayısı (uca doğru incelir).
  static const tentPennantSegments = 4;

  /// İnşa sesi ve titreşim deseni (iki kısa vuruş: "tok-tok").
  static const buildSoundAsset = 'audio/build.wav';
  static const buildVibratePattern = [0, 25, 70, 45];
  static const buildVibrateIntensities = [0, 110, 0, 200];

  /// Gölge boyu: yüksekliğin bu katı kadar sağ alta uzar (ışık sol üstten).
  static const tentShadowLength = 0.55;
  static const tentShadowOpacity = 0.18;

  /// Bu zoom altında yapılar çizilmez (uzaktan kalabalık olmasın).
  static const structureMinZoom = 13.0;

  /// İnşa animasyonu: toplam süre (ms), kamera odaklama (ms) ve zoom,
  /// squash & stretch tepe/çukur ölçeği (plan 14.1-C: 0 → %110 → %100).
  static const buildAnimMs = 1200;
  static const buildFocusMs = 450;
  static const buildFocusZoom = 16.5;
  static const buildStretch = 1.12;
  static const buildSquash = 0.92;
  static const buildDustPuffs = 9;
  static const buildDustPuffsLite = 4;

  /// Adım 2.4: seviye → yapı adı ve kurulum fiyatı (indeks = seviye).
  /// Fiyatlar sunucudaki `build_cost_<seviye>` ile aynı (sadece gösterim).
  static const structureNames = ['', 'Çadır', 'Ev', 'Otel', 'Gökdelen'];
  static const structureEmoji = ['', '⛺', '🏠', '🏨', '🏙️'];
  static const buildCosts = [0, 100, 600, 3000, 15000];
  static const maxStructureLevel = 4;

  /// Kurulum animasyonu (indeks = yeni seviye). Her seviye bir öncekinden
  /// daha büyük an (plan 14.1-D: büyük anlar 1,5 sn'yi aşabilir): süre (ms),
  /// kamera zoom'u (yüksek yapı sığsın), kurulumun bittiği oran (sonrası
  /// final kutlaması). Gökdelende ~120 ms/kat.
  static const buildAnimMsByLevel = [0, 1200, 2300, 2900, 4200];
  static const buildFocusZoomByLevel = [0.0, 16.5, 16.4, 16.1, 15.4];
  static const buildAssembleEndByLevel = [0.0, 1.0, 0.74, 0.72, 0.74];

  /// Yükseltmede eski yapının küçülerek kaybolma süresi (ms).
  static const upgradeShrinkMs = 450;

  /// Final efektleri (indeks = seviye): yağan sikke, konfeti, havai fişek
  /// patlaması sayısı. Düşük donanımda üçte biri.
  static const finaleCoins = [0, 0, 12, 18, 26];
  static const finaleConfetti = [0, 0, 0, 26, 44];
  static const finaleFireworks = [0, 0, 0, 0, 3];

  /// Gökdelen kat sayıları (alttan üste üç kademe) ve kat yüksekliği
  /// (hücre yarıçapına oran). Her [skyFloorTickEvery] katta hafif titreşim.
  static const skyTierFloors = [8, 6, 4];
  static const skyFloorHeight = 0.05;
  static const skyFloorTickEvery = 3;

  /// Final sesi/titreşimi (seviye ≥ 2): sikke sesi, otel+ claim tınısı.
  static const finaleVibratePattern = [
    <int>[],
    <int>[],
    [0, 30, 60, 60],
    [0, 40, 50, 40, 50, 90],
    [0, 60, 40, 60, 40, 60, 40, 160],
  ];
  static const finaleVibrateIntensities = [
    <int>[],
    <int>[],
    [0, 120, 0, 200],
    [0, 140, 0, 170, 0, 230],
    [0, 160, 0, 190, 0, 220, 0, 255],
  ];

  /// Adım 2.3: gelir. Kasa sunucudan bu aralıkla (sn) yeniden sorulur
  /// (oran/tavan sunucudaki `income_per_hour_<seviye>` / `income_cap_hours`).
  static const incomePollSec = 60;

  /// Toplama animasyonu: toplam süre (ms), uçan sikke sayısı (tüm yapılar
  /// için; düşük donanımda azı), sikkeler arası gecikme oranı ve yay yüksekliği.
  static const collectAnimMs = 1300;
  static const collectCoins = 14;
  static const collectCoinsLite = 5;
  static const collectStagger = 0.35;
  static const collectArc = 90.0;

  /// Toplama sesi; tekrarlarda ton bu aralıkta hafifçe değişir (plan 14.1-D).
  static const collectSoundAsset = 'audio/collect.wav';
  static const collectPitchJitter = 0.06;
  static const collectVibrateMs = 30;
  static const collectVibrateAmplitude = 90;

  /// Ayarlar ekranı gelene kadar sabit: ses / titreşim açık mı.
  static const hapticsEnabled = true;
  static const soundEnabled = true;

  /// Claim sesi (assets/ altında yol, `audio/` ile başlar) ve titreşim.
  static const claimSoundAsset = 'audio/claim.wav';
  static const claimVibrateMs = 80;
  static const claimVibrateAmplitude = 160; // 1–255
}
