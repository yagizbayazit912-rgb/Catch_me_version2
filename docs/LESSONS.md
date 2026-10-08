# 📒 Öğrenme Günlüğü (LESSONS.md)

Bu dosya projenin **hafızasıdır**. Agent aynı hatayı iki kez yapmasın, işe yarayan yöntemi tekrar bulmaya uğraşmasın diye var.

## Nasıl kullanılır
- **Adım başında:** Sadece aşağıdaki **"Altın Kurallar"** bölümünü oku (günlüğün tamamını değil, token tasarrufu).
- **Adım sonunda:** "Günlük" bölümünün en üstüne yeni bir giriş ekle (şablon aşağıda). Hata olmadıysa da iyi giden bir şeyi yaz.
- **Bir hata ikinci kez olursa** veya bir yöntem iki kez işe yararsa → Altın Kurallar'a tek satır olarak ekle.
- **Dosya ~150 satırı geçerse:** eski girişleri kısaltıp Altın Kurallar'a damıt, ham halini `docs/LESSONS_ARCHIVE.md`'ye taşı.
- Yazarken dürüst ol: Neyin denendiğini, neyin gerçekten çalıştığını yaz. "Çalışması gerekir" ≠ "test ettim, çalıştı".

---

## 🏅 Altın Kurallar

### Ön bilgi (projede henüz doğrulanmadı — doğruladıkça ✔ koy, yanlışsa düzelt)
- [ ] Android 10+ arka plan konumu: önce ön plan izni, sonra ayrı bir "her zaman izin" adımı ister. Kalıcı takip için foreground service + bildirim gerekir.
- [x] ✔ Supabase tablolarında RLS kapalıysa veriler herkese açık kalır. Her yeni tabloda RLS ve politika aynı adımda yazılır; ayrıca Supabase varsayılan grant'leri `revoke all` ile geri alınır (Adım 0.6).
- [ ] H3 indeksi `string` olarak saklanır; çözünürlük sabit kodlanmaz (config: şimdilik Res 9).
- [x] ✔ Haritada tüm altıgenleri çizme; sadece görünür alanı çiz/önbelleğe al (Adım 1.4: kamera durunca görünür hücreler + 60 sn TTL önbellek, cihazda çalıştı).
- [ ] Emülatörde konum simülasyonu gerçek GPS gürültüsünü göstermez; hız/doğruluk filtreleri gerçek cihazda ayrıca test edilmeli.
- [x] ✔ Fill-extrusion + kare başına `setLayerProperties` ile yükseklik animasyonu `maplibre_gl` 0.27.1'de Android'de çalışıyor (Adım 0.5, ~119 güncelleme/sn). Not: Adım 1.4'te animasyon tek hücrelik ayrı katmana alındı (maliyet sahipli sayısından bağımsız olmalı), ama çok sahipli altıgenle cihazda ölçüm **henüz yapılmadı** — çok bölge olunca tekrar bak.
- [ ] Animasyonlar (partikül, konfeti) düşük donanımlı Android'de kare düşürebilir; yedek mod (basit animasyon) şart.
- [x] ✔ Hile kontrolünde **ihlal/askı** sadece imkânsız durumlara (mock bildirimi, ~0 m doğruluk, >90 m/s); sınırdaki durumlar (hızlı tren, kötü GPS, uzun aradan sonra yer değişimi) sadece ret veya kontrol dışı. Yanlış askı gerçek oyuncuyu kaçırır (Adım 1.5, cihazda doğrulandı).

### Doğrulanmış kurallar
- `SUPABASE_URL` sadece proje kökü olmalı (`https://xxx.supabase.co`); `/rest/v1/` eki auth'ta "invalid path" hatası verir. `.env` değişince uygulama tamamen yeniden başlatılmalı (dart-define derlemede gömülür). (Adım 0.6)
- `maplibre_gl` `setLayerProperties` null alanları atlamıyor; animasyonda tek özellik göndermek diğerlerini varsayılana (siyah) sıfırlar, her karede tüm özellikler gönderilmeli. (Adım 0.5)

---

## 📝 Günlük (en yeni en üstte)

### Giriş şablonu
```
### [Tarih] Adım X.Y — Kısa başlık
✅ İyi giden: ...
❌ Hata / sorun: ...   (ne oldu → sebebi → nasıl çözüldü)
📌 Çıkarılan kural: ...   (yoksa "—")
⏱️ Zorlandığım yer / token yiyen şey: ...   (opsiyonel)
```

### [2026-10-09] Adım 1.6 — Yürüyüş modu
✅ İyi giden: `WalkController` (ayrı dosya) geolocator'ın `getPositionStream` + `foregroundNotificationConfig` ile foreground service ve "Catch Me aktif" bildirimini açar; her 15 sn'de bir mevcut `location-ping`'e yollar (yeni sunucu kodu yok). >25 km/s (2 ardışık okuma) → ping atmadan duraklar, 2 yavaş okumada devam. Bildirim izni için `permission_handler`. Eşikler/metinler `GameConfig`'te. Geçici "Ping gönder" ve "Claim animasyonu dene" çipleri kalktı; claim kutlaması artık yürüyüş ping'inden tetiklenir. `flutter analyze` temiz, test geçti.
❌ Hata / sorun: Durdurunca bildirim gitmedi. Sebep: `enableWakeLock: true` ama manifest'te `WAKE_LOCK` izni yoktu → eklenti `SecurityException` ("Failed to open event stream") ile akışı düzgün açamadı, servis kapanmadı. `WAKE_LOCK` eklenince çözüldü (cihazda doğrulandı: başlat/durdur, bildirim gidiyor). Ekran kapalı 10 dk yürüyüş testi **henüz yapılmadı**. Android 13+ bildirim izni reddedilirse bildirim görünmeyebilir (durum satırı uyarır).
📌 Çıkarılan kural: Eklenti izin hatası sessiz kalabilir; "çalışıyor ama durmuyor" tipi hatada önce `adb logcat -d` ile `SecurityException` ara. Bildirim/servis özelliği açılınca gereken manifest izinleri aynı adımda eklenir.

### [2026-10-01] Adım 1.5 — Temel hile kontrolleri
✅ İyi giden: Mevcut 1.1 filtreleri korundu, eşikleri `game_config`'e taşındı (`ping_guard` RPC tek çağrıda eşik + aktif askı döner, eşik eksikse 500 = kapalı başarısız). Yeni: `anticheat_events` (sadece h3, koordinat yok) + `user_risk`, `record_violation` pencerede 3 ihlalde 15 dk askı. İhlal: mock bildirimi, doğruluk <1 m, >90 m/s; 30–90 m/s sadece ret. Ret edilen ping `accrue_presence`'a hiç ulaşmaz. İstemci çipi Türkçe neden + askı bitiş saati gösteriyor. `flutter analyze` temiz, test geçti.
❌ Hata / sorun: 1.1'deki gizli hata: teleport reddi son durumu güncellemediği için uçak/tren sonrası yeni şehirde her ping sonsuza dek "teleport" olurdu (askıyla birleşince kalıcı ceza) → son geçerli ping'ten 30 dk sonra hız kontrolü atlanıyor. Dart string'inde iç içe tırnak + `'` analyzer'ı bozdu → ek metin ayrı değişkene alındı. Yerelde Deno yok, fonksiyon cihazda doğrulanacak.
✅ Kullanıcı cihazda doğruladı: sahte konum uygulamasıyla `mock_location` reddi + 3. ihlalde askı, sahte uygulama kapalıyken de askı sürdü; `ping_state` 111 km kaydırılınca `teleport` reddi + askı; `hex_progress` değişmedi (kendi bölgesinde durduğu için zaten kayıt yok). Not: sahte konum uygulamasında "Başlat"a basılmadan telefon gerçek konumu verir → ping ok (kod hatası değil).
📌 Çıkarılan kural: "Ret durumu güncellemez" kuralı her zaman bir kaçış yolu (zaman aşımı) ile birlikte yazılır, yoksa kullanıcı kilitlenir.

### [2026-10-01] Adım 1.4 — Sahipli altıgenlerin renkli/yükseltilmiş çizimi
✅ İyi giden: RPC `owned_hexes_in(text[])` (security definer, sadece authenticated; `hexes` kapalı kalır). İstemci görünür alanı (+%15 pay) h3'e çevirip sadece önbellekte olmayan/60 sn'den eski hücreleri sorar; dönen sadece h3 + is_mine + color_seed (owner_id/koordinat yok). Sahipliler tek fill-extrusion katmanında, renk veriden (`['get','color']`): kendi = `AppColors.ownHex`, diğerleri `otherPlayerPalette[seed % n]`. Yükselme animasyonu ayrı tek-hücreli katmanda → kare başı `setLayerProperties` maliyeti sahipli sayısından bağımsız. Claim'de `res.h3` önbelleğe eklenir. `flutter analyze` temiz, test geçti.
✅ Kullanıcı cihazda doğruladı: kendi bölge nane yeşili blok; SQL ile ikinci hesaba devredilince şeftali renkte göründü, geri alınınca TTL içinde yeşile döndü. ❌ Hata / sorun: Çok sahipli altıgenle performans cihazda ölçülmedi. >600 hücre (uzak zoom) → sahiplik çizilmiyor. "3D yükselt" çipi artık claim olmadan görünür blok göstermez ("Claim dene" bulunduğun hücreyi yükseltir).
📌 Çıkarılan kural: Animasyonlu yükseklik ayrı küçük katmanda; toplu veriler sabit katmanda veri-güdümlü ifadeyle.

### [2026-10-01] Adım 1.3 — Sahiplenme animasyonu, haptik, ses
✅ İyi giden: `ClaimCelebration` (ripple halkaları, parıltılar, "+1 Bölge" süzülür) + `playClaimFeedback` (orta haptik + sistem sesi) ayrı dosyada. Tetik sunucudan: `PingResult.claimed` (`presence.status == 'claimed'`). Süre/parçacık sayısı/ses-titreşim bayrağı `GameConfig`'te. Sadece etiket dokunma yakalar (dokununca atlanır), harita çalışmaya devam eder; "hareketi azalt" → animasyonsuz kısa bildirim. Yeni paket yok. `flutter analyze` temiz, test geçti.
❌ Hata / sorun: `SystemSound.click` + `HapticFeedback` telefonun sistem ayarına bağlı (Samsung'ta kapalı) → `audioplayers` + `vibration`'a geçildi. Tek `AudioPlayer`'ı tekrar çalmak (lowLatency) ilk seferden sonra susturdu → her claim'de yeni oynatıcı. Sürekli kayan perde + gürültü "matkap" gibi duyuldu → ayrık basamaklı notalara çevrildi. ✅ Kullanıcı cihazda doğruladı (animasyon, titreşim, ses). Komşu altıgen ripple'ı overlay halkasıyla yaklaşıldı (gerçek komşu dalgalanması 1.4'te sahipli çizimle).
📌 Çıkarılan kural: Ses/titreşim sistem ayarlarına (touch sounds/haptic) bağlı API'lerle yapılmaz; medya sesi + titreşim motoru kullanılır. Tekrar çalınan sesler için her seferinde yeni oynatıcı.

### [2026-10-01] Adım 1.2 — Presence birikimi ve sahiplenme
✅ İyi giden: Migration `20261001020000_presence_claim.sql`: `game_config` (claim_seconds=600, pencere 24 sa, ping başına tavan 60 sn, sahiplik limiti 5), `hexes`, `hex_progress`, hepsi RLS + revoke (sadece service_role). Birikim ve claim tek atomik SQL fonksiyonunda (`accrue_presence`, sadece service_role çağırır); `location-ping` her kabul edilen ping'te çağırıyor. Süre = aynı altıgendeki ardışık ping farkı (altıgen değişimi/ilk ping 0 sn, araç hızında sayılmaz).
❌ Hata / sorun: Yerelde CLI/Deno yok → yerelde test edilemedi. ✅ Kullanıcı cihazda doğruladı (claim_seconds=30 ile test, bölge `hexes`'e kullanıcıya yazıldı, sonra 600'e geri alındı). Not: uygulama `--dart-define-from-file=.env` olmadan açılınca "Supabase ayarı bulunamadı" gösterir; panelde "Failed to fetch" geçici bağlantı sorunuydu. Sahipli (başkasının) bölgede meydan okuma henüz yok, sadece birikim sürüyor.
📌 Çıkarılan kural: Oyun sayıları `game_config` tablosunda; sunucu fonksiyonu okur, koda gömülmez.

### [2026-10-01] Adım 1.1 — location/ping servisi
✅ İyi giden: Edge Function `location-ping` (tek dosya, h3-js ile sunucuda h3 hesabı; doğruluk >50 m, ışınlanma >30 m/s, mock bildirimi, bayat ping reddi; >25 km/s kabul ama varlık sayılmaz). `ping_state` tablosu RLS + revoke (politikasız, sadece service_role). İstemci `PingRepository` + haritada geçici "Ping gönder" çipi (sunucu h3 ↔ yerel h3). `flutter analyze` temiz.
❌ Hata / sorun: Yerelde Supabase CLI/Deno yok → fonksiyon çalıştırılıp test edilemedi; sadece analyze ile doğrulandı. Kullanıcı cihazda doğruladı: migration + deploy sonrası ping ok, sunucu h3 (892d114a543ffff) yerel hesapla eşleşti. Not: Dashboard editörüne dosya adı değil içerik yapıştırılır; fonksiyon adı tam `location-ping` olmalı.
📌 Çıkarılan kural: Reddedilen ping son durumu güncellemez; hız hesabında iki ölçümün doğruluğu mesafeden düşülür (GPS gürültüsü sahte ışınlanma üretmesin).

### [2026-10-01] Adım 0.7 — Google ile giriş
✅ İyi giden: `google_sign_in` 7.x yerel akış (`authenticate()` → ID token → Supabase `signInWithIdToken`); tarayıcı yönlendirmesi yok. Giriş ekranına "Google ile devam et" eklendi, `GOOGLE_WEB_CLIENT_ID` `.env`'den okunuyor (secret repoda/istemcide yok). `flutter analyze` temiz. Kullanıcı cihazda doğruladı: Google girişi + e-posta girişi çalışıyor.
❌ Hata / sorun: Supabase "Client IDs" alanına istemci adı (`catch-me`) yazılmıştı → Web client ID (`...apps.googleusercontent.com`) olmalı. Test users listesinde olmayan hesap da girebildi (sebep kesinleşmedi: proje üyesi ya da temel kapsamda kısıt uygulanmıyor olabilir).
📌 Çıkarılan kural: Supabase Google sağlayıcısına **Web** client ID + secret girilir ("Skip nonce checks" açık); Android client sadece paket adı + SHA-1 kaydı içindir. Test users listesi erişim kontrolü sayılmaz; erişim kısıtı sunucuda. Release için ayrı SHA-1 ve Google uygulama yayını/doğrulaması gerekecek.

### [2026-10-01] Adım 0.6 — Supabase + auth + users + RLS
✅ İyi giden: `supabase_flutter` 2.18 eklendi; URL/anahtar `--dart-define-from-file=.env` ile (asset'e gömülmez, `.env` gitignore'da, `git check-ignore` ile doğrulandı). `users` tablosu + kayıt tetikleyicisi + RLS migration'ı ve SQL Editor'de çalışan, kendini geri alan RLS testi (`supabase/tests/rls_users.sql`) yazıldı. `flutter analyze` temiz, mevcut test geçti.
❌ Hata / sorun: Supabase yeni tablolarda anon/authenticated'a varsayılan TÜM yetkileri verir → sadece RLS'e güvenmek yerine `revoke all` + kolon bazlı `grant update(username)`. `anonKey` deprecated → `publishableKey`. Bash heredoc'u Türkçe kesme işaretli Dart kodunda bozuldu → Write aracı kullanıldı. Kayıtta "invalid path specified in request url" → `.env`'de URL Data API sayfasından `/rest/v1/` ekiyle kopyalanmıştı (+ şablon satırı silinmemişti) → kök URL'ye düzeltilince çözüldü.
✅ Doğrulandı (kullanıcı): migration + RLS testi Supabase'de çalıştı; cihazda kayıt → harita, çıkış → giriş çalışıyor.
📌 Çıkarılan kural: Her yeni tabloda `revoke all ... from anon, authenticated` + gereken grant'lar + RLS politikası aynı migration'da.

### [2026-10-01] Adım 0.5 — 3D deneme (spike)
✅ İyi giden: `maplibre_gl` 0.27.1 kaynağında fill-extrusion + Android `setLayerProperties` desteği doğrulandı; eğimli kamera + tek altıgen yükselme animasyonu (elasticOut, kare başına setLayerProperties) yazıldı, `flutter analyze` temiz.
✅ Cihazda (SM S721B) çalıştı: ~119 güncelleme/sn, akıcı.
❌ Hata / sorun: Extrusion bloğu siyah çıktı → 5 tahmin (renk biçimi, opaklık, gradient, veri güdümlü renk, ışık) boşa gitti. Kullanıcı "renk bir an görünüp gidiyor" deyince sebep bulundu: `setLayerProperties` null alanları varsayılana sıfırlıyor → her karede tüm özellikler gönderildi, düzeldi (cihazda doğrulandı). Cihaza adb ile bağlanıp `screencap` ile kendim test ettim: `D:/Androidsdk/platform-tools/adb`.
📌 Çıkarılan kural: `maplibre_gl` `setLayerProperties` her zaman TÜM özellikleri gönderir (eksikler varsayılana döner). Görsel hata sürerse tahmin yerine önce "ne zaman bozuluyor?" sorusunu sor.

### [2026-10-01] Adım 0.4 — H3 + düz altıgenler
✅ İyi giden: `h3_flutter_plus` (FFI) eklendi; `HexService` konum etrafında gridDisk halkasını GeoJSON olarak üretiyor, MapLibre fill+line katmanıyla çiziliyor. Çözünürlük/halka `GameConfig`'ten (Res 9, 2 halka). `flutter analyze` temiz; **Samsung SM S721B (Android 16) cihazında altıgenler göründü, kullanıcı doğruladı.**
❌ Hata / sorun: Emülatör offline kaldı, gerçek cihaz sonradan bağlandı. h3 ve maplibre'nin `LatLng` sınıfları çakışır → h3 `as h3lib` ile içe aktarıldı.
📌 Çıkarılan kural: —

### [2026-10-01] Adım 0.3 — Harita + konum izni
✅ İyi giden: MapLibre + yerel pastel stil JSON (OpenFreeMap kaynağı, anahtar yok); izin akışı (verildi / reddedildi / kalıcı red / servis kapalı) tek kartta. `flutter analyze` temiz, `flutter build apk --debug` başarılı.
❌ Hata / sorun: Emülatör "offline" çıktı → haritanın gerçekten açıldığı ve mavi konum noktasının göründüğü **cihazda doğrulanmadı**; yalnızca derleme doğrulandı. Platform view yüzünden MapScreen widget testi yazılmadı (test tema ekranına bağlandı). Gradle Kotlin artımlı önbellek uyarıları (proje D:, pub cache C:) zararsız görünüyor.
📌 Çıkarılan kural: Harita/konum adımları cihazda elle doğrulanmadan "çalışıyor" sayılmaz.
✔ Sonradan doğrulandı (kullanıcı, cihazda): harita açılıyor, konum izni ve konum görünümü çalışıyor.

### [2026-10-01] Adım 0.2 — Pastel tema
✅ İyi giden: Nunito (variable TTF, OFL) `assets/fonts/` altına paketlendi → çevrimdışı çalışır, ağ bağımlılığı yok. `AppColors`/`AppTheme` `core/theme` altında; `flutter analyze` temiz, widget testi geçti.
❌ Hata / sorun: 0.1'in testi harita metnini arıyordu, ana ekran değişince kırıldı → test güncellendi. Cihazda görsel kontrol yapılmadı; variable font ağırlıklarının (w800/w900) Android'de doğru render olduğu doğrulanmadı.
📌 Çıkarılan kural: Ana ekran (home) değişince `test/widget_test.dart` da güncellenmeli.
✔ Sonradan doğrulandı (kullanıcı, cihazda): tema ekranı, renkler, Nunito ve butonlar doğru görünüyor.

### [2026-10-01] Adım 0.1 — Flutter iskeleti
✅ İyi giden: `flutter create --project-name catch_me --platforms android .` mevcut klasörde sorunsuz çalıştı; `flutter analyze` temiz, widget testi geçti.
❌ Hata / sorun: Android cihaz/emülatörde açılış denenmedi (yalnızca analyze + widget testi).
📌 Çıkarılan kural: Klasör adı geçersiz paket adıysa `--project-name` ile ver.
✔ Sonradan doğrulandı (kullanıcı, cihazda): uygulama Android'de açılıyor.

### [Proje başlangıcı]
✅ İyi giden: Plan ve kararlar yazıldı (Catch Me, Res 9, Android önce, 13+).
📌 Çıkarılan kural: Adımlar küçük tutulur; her adım sonunda özet + commit + bu dosyaya giriş.
