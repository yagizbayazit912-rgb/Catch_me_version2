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

### [Proje başlangıcı]
✅ İyi giden: Plan ve kararlar yazıldı (Catch Me, Res 9, Android önce, 13+).
📌 Çıkarılan kural: Adımlar küçük tutulur; her adım sonunda özet + commit + bu dosyaya giriş.
