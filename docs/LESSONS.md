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
- [ ] Supabase tablolarında RLS kapalıysa veriler herkese açık kalır. Her yeni tabloda RLS ve politika aynı adımda yazılır.
- [ ] H3 indeksi `string` olarak saklanır; çözünürlük sabit kodlanmaz (config: şimdilik Res 9).
- [ ] Haritada tüm altıgenleri çizme; sadece görünür alanı çiz/önbelleğe al.
- [ ] Emülatörde konum simülasyonu gerçek GPS gürültüsünü göstermez; hız/doğruluk filtreleri gerçek cihazda ayrıca test edilmeli.
- [ ] Haritada 3D (fill-extrusion) ve altıgen yüksekliği animasyonu Flutter MapLibre paketinde nasıl destekleniyor → **Adım 0.5'te doğrulanacak**, varsayma.
- [ ] Animasyonlar (partikül, konfeti) düşük donanımlı Android'de kare düşürebilir; yedek mod (basit animasyon) şart.

### Doğrulanmış kurallar
*(Henüz yok. İlk doğrulanan kural buraya gelir.)*

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

### [2026-10-01] Adım 0.5 — 3D deneme (spike)
✅ İyi giden: `maplibre_gl` 0.27.1 kaynağında fill-extrusion + Android `setLayerProperties` desteği doğrulandı; eğimli kamera + tek altıgen yükselme animasyonu (elasticOut, kare başına setLayerProperties) yazıldı, `flutter analyze` temiz.
❌ Hata / sorun: Henüz cihazda denenmedi → sonuç DECISIONS.md'de "doğrulanmadı" olarak duruyor.
📌 Çıkarılan kural: Platform kanalına kare başına çağrı atarken önceki çağrı bitmeden yenisini atma (busy bayrağı).

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
