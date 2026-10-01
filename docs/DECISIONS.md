# Küçük Kararlar (agent notları)

- **Adım 0.1:** `flutter create --project-name catch_me --platforms android .` (klasör adı geçersiz paket adı; yalnızca Android hedefi). Organizasyon varsayılan `com.example` bırakıldı; yayın öncesi değiştirilecek.
- **Adım 0.1:** Boş klasörler `.gitkeep` ile takip ediliyor; tek boş ekran `MapScreen`.
- **Adım 0.3:** Paketler: `maplibre_gl` (harita) + `geolocator` (izin ve konum; `permission_handler` eklenmedi). Sadece ön plan izni (FINE/COARSE), arka plan yok.
- **Adım 0.3:** Harita stili API anahtarı gerektirmeyen OpenFreeMap vektör kaynağı + yerel `assets/map/pastel_style.json` (etiketsiz, bu yüzden glyph gerekmez). Stil JSON'undaki renkler palet hex'leriyle elle eşlendi (JSON `core/theme`'den okuyamaz). Yayın öncesi OpenFreeMap kullanım koşulları/ataf ve kendi tile barındırma değerlendirilecek.
- **Adım 0.3:** Başlangıç kamerası konum alınamazsa İstanbul (41.0082, 28.9784).


## Adım 0.5 — 3D deneme (spike) sonucu
- **Durum:** ✅ **Çalışıyor** — Samsung SM S721B'de eğimli kamera + yükseltilmiş altıgen + yükselme animasyonu görüldü, ~119 güncelleme/sn (kullanıcı doğruladı). Yedek plana gerek yok.
- **Açık sorun:** Blok siyah çıktı (renk düz `"#hex"` metni olarak gidiyordu). `['rgb', r, g, b]` ifadesiyle düzeltildi → ⏳ cihazda doğrulanmadı. Animasyon çok hızlı bulundu → süre 900 → 1600 ms.
- **Paket desteği (kaynak kodda kontrol edildi):** `maplibre_gl` 0.27.1 → `addFillExtrusionLayer` + `FillExtrusionLayerProperties` (height, base, color, opacity, verticalGradient) var; Android'de `layer#setProperties` FillExtrusion katmanını da güncelliyor. Kamera eğimi `CameraPosition.tilt` ile.
- **Yöntem:** Eğim `GameConfig.mapTilt` (50°). Kullanıcının hücresi ayrı kaynak + fill-extrusion katmanı. Animasyon: Dart `AnimationController` + `Curves.elasticOut`, her karede `setLayerProperties(fillExtrusionHeight)`; önceki çağrı bitmeden yenisi atılmaz. Yükseklik/süre `GameConfig`'ten (40 m, 900 ms). Hareketi azalt → anında son yükseklik.
- **Ölçüm:** Üstteki "3D tekrar • N güncelleme/sn" çipi, animasyon sırasında native katmana kaç güncelleme gittiğini gösterir (≈ akıcılık göstergesi; harita FPS'i değil).
- **Yedek plan (çalışmazsa / takılırsa):** (1) Akıcı değilse: yükseltme kalır, animasyon Flutter tarafında overlay (ölçeklenen altıgen sprite + gölge) ile oynanır, bitince katman tek seferde son yüksekliğe ayarlanır. (2) Fill-extrusion hiç görünmezse: altıgenler düz çizilir, yükseklik hissi sprite + blob gölge ile verilir (PROJE_PLANI 14.1-A yedek yolu).
