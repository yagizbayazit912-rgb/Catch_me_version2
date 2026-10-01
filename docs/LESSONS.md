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
- [ ] Haritada tüm altıgenleri çizme; sadece görünür alanı çiz/önbelleğe al.
- [ ] Emülatörde konum simülasyonu gerçek GPS gürültüsünü göstermez; hız/doğruluk filtreleri gerçek cihazda ayrıca test edilmeli.
- [x] ✔ Fill-extrusion + kare başına `setLayerProperties` ile yükseklik animasyonu `maplibre_gl` 0.27.1'de Android'de çalışıyor (Adım 0.5, ~119 güncelleme/sn). Not: sahipli çok altıgenle performans Adım 1.4'te yeniden test edilecek.
- [ ] Animasyonlar (partikül, konfeti) düşük donanımlı Android'de kare düşürebilir; yedek mod (basit animasyon) şart.

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
