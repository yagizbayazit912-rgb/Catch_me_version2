# Küçük Kararlar (agent notları)

- **Adım 0.1:** `flutter create --project-name catch_me --platforms android .` (klasör adı geçersiz paket adı; yalnızca Android hedefi). Organizasyon varsayılan `com.example` bırakıldı; yayın öncesi değiştirilecek.
- **Adım 0.1:** Boş klasörler `.gitkeep` ile takip ediliyor; tek boş ekran `MapScreen`.
- **Adım 0.3:** Paketler: `maplibre_gl` (harita) + `geolocator` (izin ve konum; `permission_handler` eklenmedi). Sadece ön plan izni (FINE/COARSE), arka plan yok.
- **Adım 0.3:** Harita stili API anahtarı gerektirmeyen OpenFreeMap vektör kaynağı + yerel `assets/map/pastel_style.json` (etiketsiz, bu yüzden glyph gerekmez). Stil JSON'undaki renkler palet hex'leriyle elle eşlendi (JSON `core/theme`'den okuyamaz). Yayın öncesi OpenFreeMap kullanım koşulları/ataf ve kendi tile barındırma değerlendirilecek.
- **Adım 0.3:** Başlangıç kamerası konum alınamazsa İstanbul (41.0082, 28.9784).


## Adım 0.5 — 3D deneme (spike) sonucu
- **Durum:** ✅ **Çalışıyor** — Samsung SM S721B'de eğimli kamera + yükseltilmiş altıgen + yükselme animasyonu görüldü, ~119 güncelleme/sn (kullanıcı doğruladı). Yedek plana gerek yok.
- **Siyah blok sorunu (çözüldü ✅, cihazda ekran görüntüsüyle doğrulandı):** `maplibre_gl`'in `setLayerProperties`'i null alanları atlamıyor (`skipNulls: false`); animasyonda yalnızca yükseklik gönderilince renk/opaklık varsayılana (siyah) sıfırlanıyordu. Çözüm: `_hex3dProps(height)` ile her karede tüm özellikler gönderiliyor. (Denenip işe yaramayanlar: rgb ifadesi, opaklık 1.0, vertical gradient kapalı, veri güdümlü renk, stil `light`.) Animasyon süresi 1600 ms.
- **Paket desteği (kaynak kodda kontrol edildi):** `maplibre_gl` 0.27.1 → `addFillExtrusionLayer` + `FillExtrusionLayerProperties` (height, base, color, opacity, verticalGradient) var; Android'de `layer#setProperties` FillExtrusion katmanını da güncelliyor. Kamera eğimi `CameraPosition.tilt` ile.
- **Yöntem:** Eğim `GameConfig.mapTilt` (50°). Kullanıcının hücresi ayrı kaynak + fill-extrusion katmanı. Animasyon: Dart `AnimationController` + `Curves.elasticOut`, her karede `setLayerProperties(fillExtrusionHeight)`; önceki çağrı bitmeden yenisi atılmaz. Yükseklik/süre `GameConfig`'ten (40 m, 900 ms). Hareketi azalt → anında son yükseklik.
- **Ölçüm:** Üstteki "3D tekrar • N güncelleme/sn" çipi, animasyon sırasında native katmana kaç güncelleme gittiğini gösterir (≈ akıcılık göstergesi; harita FPS'i değil).
- **Yedek plan (çalışmazsa / takılırsa):** (1) Akıcı değilse: yükseltme kalır, animasyon Flutter tarafında overlay (ölçeklenen altıgen sprite + gölge) ile oynanır, bitince katman tek seferde son yüksekliğe ayarlanır. (2) Fill-extrusion hiç görünmezse: altıgenler düz çizilir, yükseklik hissi sprite + blob gölge ile verilir (PROJE_PLANI 14.1-A yedek yolu).

## Adım 0.6 — Supabase / auth
- **Gizli ayar:** `flutter_dotenv` yerine `--dart-define-from-file=.env` (dosya APK asset'i olmaz). Şablon `.env.example`; VS Code `launch.json` bu argümanla çalıştırır. `.env` yoksa uygulama çökmez, uyarı ekranı gösterir. Not: publishable anahtar istemcide zaten açıktır; güvenlik RLS'tedir. `sb_secret_`/service_role istemciye asla girmez.
- **Giriş yöntemi:** Şimdilik e-posta + şifre (deep link gerektirmez). Google ile giriş / misafir hesabı sonraya. Geliştirmede "Confirm email" kapalı olabilir; **yayından önce açılacak**.
- **users RLS:** Kullanıcı sadece kendi satırını okur, sadece `username` güncelleyebilir; insert yalnızca `handle_new_user` tetikleyicisi (security definer), delete auth cascade ile. Başkalarının profili (liderlik vb.) ileride kısıtlı görünüm/fonksiyonla açılacak.
- **Kullanıcı adı:** `^[A-Za-z0-9_]{3,20}$` (DB check + istemci doğrulama). Alınmışsa/geçersizse tetikleyici `oyuncu_xxxxxxxx` atar. Moderasyon sonraki adımlarda.
- **Çıkış butonu:** Geçici olarak harita sağ üstte; profil ekranına taşınacak.

- **Google girişi:** Google girişi 0.6'dan ayrı bir adım (0.7). Adım 1.1 ve sonrasını engellemez, kapalı beta öncesi tamamlanmalı. 0.7'de doğrulanacaklar: debug ve release için ayrı SHA-1 parmak izleri, Supabase geri dönüş (redirect) adresi, Google Cloud hesabını ve anahtarları kullanıcının oluşturması. iOS'a geçilirken Apple'ın üçüncü taraf girişle birlikte 'Apple ile giriş' isteyip istemediği güncel kurallardan kontrol edilecek.

## Adım 1.1 — location/ping
- **Sunucu katmanı:** Supabase Edge Function `location-ping` (Postgres'te h3 eklentisi yok). Tek dosya; sayılar dosya başındaki `CONFIG` bloğunda (ileride config tablosuna taşınacak). `H3_RESOLUTION` istemcideki `GameConfig.h3Resolution` ile elle senkron tutulmalı.
- **Filtreler:** doğruluk >50 m ret; hesaplanan hız >30 m/s ret ("teleport"); istemci `isMocked` bildirirse ret; istemci zamanı 120 sn'den eskiyse ret. Hız sunucuda son geçerli ping'den hesaplanır (istemci hızına güvenilmez); mesafeden iki doğruluk değeri düşülür. Hız >25 km/s ise ping kabul edilir ama `counts_for_presence=false` (1.2 kullanacak).
- **ping_state:** son geçerli ping tek satır/kullanıcı; istemci erişimi yok (RLS politikasız + revoke). Ham koordinat kimseye dönmez, cevap sadece çağıranın kendi h3'ünü içerir.
- **Test çipi:** haritadaki "Ping gönder" geçici; Adım 1.6'da yürüyüş modu ping'i otomatik atınca kalkacak. Mock tespiti şimdilik istemci bildirimine bağlı, sunucu tarafı risk skoru Adım 1.5.

## Adım 1.3 — Claim animasyonu
- **Ses/titreşim:** `audioplayers` (medya sesi, her claim'de yeni oynatıcı, tekrarlarda ton hafif yükselir) + `vibration` paketi (sistem "touch feedback" ayarından bağımsız; motor yoksa `HapticFeedback`). Ses `assets/audio/claim.wav`: Python ile sentezlendi (basamaklı yükseliş + hava + pop + glockenspiel üçlüsü, ~1 sn). Ayarlar ekranı gelene kadar `GameConfig.soundEnabled/hapticsEnabled` sabit.
- **Overlay:** Kutlama ekran-merkezli Flutter overlay'i (harita native katman olduğu için dünya koordinatına bağlanmaz). Düşük donanım tespiti yok; `lite` bayrağı hazır, tespit sonra bağlanacak.
- **Test çipi:** "Claim animasyonu dene" geçici; Adım 1.6'da ping çipiyle birlikte kalkacak.

## Adım 1.4 — Sahipli altıgen çizimi
- **Okuma:** `owned_hexes_in(text[])` RPC; istemci görünür hücreleri gönderir (Postgres'te h3 yok, bbox sorgusu yapılamaz). Hücre sınırı `game_config.max_visible_hexes` = `GameConfig.maxVisibleHexes` (600, elle senkron). Dönen: h3, is_mine, color_seed (owner_id hash'i, 0–999). Sahibin kimliği/adı yok; gerekirse ileride kısıtlı görünümle.
- **Renk:** kendi bölge `AppColors.ownHex` (nane), diğerleri `otherPlayerPalette` (nane hariç). Aynı renge düşen farklı oyuncular olabilir; oyuncu renk seçimi kozmetik adımında.
- **Önbellek:** hücre başına 60 sn TTL (`GameConfig.ownedCacheTtlSec`), sadece görünür sahipliler çizilir. Gerçek zamanlı güncelleme (başkası claim edince) yok; TTL ile yenilenir.
- **Yükseklik:** tüm sahipliler `hexExtrusionHeight`; yapı seviyesine göre yükseklik yapılar adımında.

## Adım 1.5 — Hile kontrolleri
- **Kapsam:** Basit risk skoru bu adımda: ihlaller `anticheat_events`'e yazılır, `anticheat_strike_window_s` (1 sa) içinde `anticheat_strikes_to_suspend` (3) ihlalde `anticheat_suspend_s` (15 dk) askı; askıdayken tüm ping'ler `suspended` ile reddedilir. Kalıcı ban, itiraz, admin paneli yok (sonra).
- **İhlal sayılanlar:** `mock_location` (istemci bildirimi), `implausible_accuracy` (<`ping_min_accuracy_m`=1 m; gerçek GPS ~0 bildirmez), `teleport` > `anticheat_strike_speed_mps` (90 m/s). 30–90 m/s ve kötü doğruluk/bayat ping sadece ret, ihlal değil.
- **Uzun ara:** `ping_teleport_max_gap_s` (30 dk) sonrası hız kontrolü yapılmaz (uçak/tren sonrası kilitlenme olmasın). Bedeli: hileci 30 dk bekleyip sıçrayabilir; mock bildirimi gizleyen (root) istemci için kabul edildi.
- **Eşikler:** 1.1'deki `CONFIG` bloğu kaldırıldı, hepsi `game_config`'te. Sadece `H3_RESOLUTION` kodda (istemciyle senkron).
- **Gizlilik:** İhlal kaydında koordinat yok, sadece h3 + hız + doğruluk. Tablolar sadece service_role.
- iOS mock tespiti (sadece hız/sıçrama) iOS'a geçerken tekrar ele alınacak.

## Sonraya kalanlar (bölüm 19 listesi bitince ele alınacak)
- **Devralma (PROJE_PLANI 5.3):** Bölüm 19'da hiçbir adıma bağlı değil. `accrue_presence` sahipli bölgede süreyi biriktiriyor ama devralma yapmıyor (`owned_by_other`). Temel mekanik; ayrı adım olarak eklenmeli (yürüyüş modu 1.6'dan sonra test edilebilir). Uyarı ve kayıp bildirimleri de bu kapsamda.
- **Bölge el değiştirme animasyonu:** Sahip değişince (kaybetme/devralma) renk sessizce güncelleniyor; bölüm 14.1'de tarifi yok. Cila turunda tasarlanacak.
