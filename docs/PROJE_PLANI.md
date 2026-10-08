# 🌍 Catch Me — Proje Planı

> Gerçek dünya haritasını altıgen bölgelere ayıran, konum tabanlı, sosyal ve ekonomi odaklı mobil oyun.
> Bu dosya Antigravity (IDE agent) için ana referans belgesidir. Agent, yeni bir göreve başlamadan önce bu dosyayı okumalıdır.

**Not:** "Öneri" etiketli maddeler değiştirilebilir teknik/tasarım kararlarıdır. Sayısal değerler (fiyat, gelir, süre) başlangıç tahminidir ve `config` üzerinden ayarlanabilir olmalıdır, koda gömülmemelidir.

---

## 1. Vizyon

Oyuncular gerçek dünyada gezerek altıgen bölgeleri sahiplenir. Bölgelerine çadır, ev, otel ve gökdelen dikip işletir, pasif gelir kazanır. Başka bir oyuncunun bölgesine giren kişi **kira öder**. Kazanılan paralar ile bölgeler geliştirilir, karakter kozmetikleri alınır.

**Hissiyat:** Tatlı, ferah, rekabetten çok keşif ve sosyalleşme odaklı. Stresli değil, "bir bakayım ne kazanmışım" dedirten bir oyun.

**Tek cümle:** *"Gezdiğin yer senin olur, sahip olduğun yer sana kazandırır."*

---

## 2. Temel Oyun Döngüsü

```
Dışarı çık / gez → Bölgede süre geçir → Bölgeyi sahiplen
        ↑                                      ↓
Kira öde / kazan ← Başkalarının bölgesine gir   Yapı inşa et (çadır → ev → otel → gökdelen)
        ↑                                      ↓
Kozmetik al, karakteri geliştir ← Gelir topla ←┘
```

Günlük döngü: Uygulamayı aç → biriken geliri topla → günlük görevleri gör → gezerken bölge sahiplen → akşam kira/istatistik özeti.

---

## 3. Önerilen Teknoloji Yığını (Öneri)

| Katman | Seçim | Neden |
|---|---|---|
| Mobil | **Flutter** (iOS + Android tek kod) | Hızlı UI, güzel animasyonlar, Antigravity ile uyumlu |
| Harita | **MapLibre GL** (alternatif: Mapbox) | Özelleştirilebilir pastel stil, altıgen katman çizimi, eğimli kamera ve 3D yükseltme (fill-extrusion) desteği (Adım 0.5'te doğrulanacak) |
| Altıgen sistem | **Uber H3** | Dünya çapında hazır altıgen ızgara, komşuluk ve hiyerarşi hesapları hazır |
| Backend | **Supabase** (PostgreSQL + PostGIS + Auth + Realtime + Edge Functions) | Hızlı başlangıç, gerçek zamanlı, ölçeklenebilir |
| Arka plan işleri | Supabase Cron / Edge Functions | Gelir hesaplama, sezon sıfırlama |
| Bildirim | Firebase Cloud Messaging | Kira, saldırı, gelir bildirimleri |
| Ödeme | RevenueCat (uygulama içi satın alma) | iOS/Android abonelik ve satın alma yönetimi |
| Analitik / Hata | Firebase Analytics + Crashlytics (veya Sentry) | |
| State yönetimi | Riverpod | |
| Animasyon | Flutter animasyonları + **Rive** (karakter/yapı animasyonu) + partikül/konfeti paketi | Tatmin edici "juice" efektleri |
| Ses / titreşim | Kısa ses efektleri + cihaz haptik geri bildirimi | Dokunsal tatmin hissi |

**Altın kural:** Sunucu otorite kaynağıdır (server-authoritative). İstemci sadece konum **bildirir**; sahiplik, para, kira gibi tüm kararları sunucu verir. Aksi halde hile kaçınılmazdır.

---

## 4. Harita ve Altıgen Sistem

- Altıgenler için **H3 indeks** kullanılır. Her bölgenin benzersiz ID'si H3 indeksidir (ör. `8a2a1072b59ffff`).
- **Çözünürlük önerisi:**
  - Res 9 → kenar ≈ 174 m, alan ≈ 0.1 km² (mahalle hissi, daha az bölge)
  - Res 10 → kenar ≈ 66 m, alan ≈ 0.015 km² (sokak hissi, yürüyerek daha hızlı bölge kazanımı)
  - ✅ **KARAR: Res 9 (büyük, ~174 m)** ile başlanır. Çözünürlük yine de `config`'ten değiştirilebilir olmalı; saha testinde sahiplenme süresi (10 dk) gerekirse ayarlanır.
- Harita stili: pastel, sade, etiketleri az. Sahipli altıgenler sahibinin rengiyle yarı saydam doldurulur.
- Altıgen üzerinde yapı ikonu/3D-izometrik küçük illüstrasyon gösterilir.
- Haritada sadece ekranda görünen altıgenler sorgulanır (viewport bazlı, sayfalama/önbellek).

---

## 5. Bölge Sahiplenme Mekaniği

### 5.1 Varlık (presence) ve süre
- Oyuncu bir altıgenin içindeyken **"varlık puanı"** birikir. Örnek: bölgede **10 dakika** cumulative kalınca sahiplenilir.
- Süre kesintisiz olmak zorunda değil, **toplam birikim** sayılır (ör. 24 saat içinde toplam 10 dk).
- Sahipsiz bölge ilk ulaşan oyuncuya geçer. Sahipli bölgeye birikim yapılırsa "meydan okuma" (bkz. 5.3).

### 5.2 Sahiplik limitleri
- Başlangıçta en fazla **N bölge** (ör. 5). Seviye arttıkça limit artar.
- Bir bölge 30 gün ziyaret edilmez ve yapısı yoksa **sahipsiz kalabilir** (çürüme / decay). Yapısı olan bölgeler çürümez ama gelir toplamazsa verimi düşer.

### 5.3 Meydan okuma / devralma (✅ Karar: yapısız bölge 30 dk toplam sürede devralınabilir)
- Başka bir oyuncu, sahipli bölgede belirli bir süre (ör. 30 dk toplam) geçirirse **devralma hakkı** kazanır.
- Sahibin yapısı varsa devralma mümkün değildir; bunun yerine "kuşatma" yerine sadece **kira** ödenir. (Yapı = koruma.)
- Bu, yapı yapmayı teşvik eder ve tatsız hırsızlık hissini azaltır.
- Bölgesini kaybeden oyuncuya bildirim gider ("X bölgeni devraldı"). Sürpriz kayıp hissini azaltmak için devralmadan önce **uyarı bildirimi** (ör. "Biri bölgende 20 dk geçirdi") gönderilir.

### 5.4 Hile önleme (kritik)
- Sahte konum (mock location) tespiti: Android `isMockLocation`, iOS için hız/sıçrama analizi.
- Hız kontrolü: Mantıksız hızda (ör. >30 m/s ışınlanma) gelen konumlar reddedilir.
- Araçta gezmeyi sınırlama: hız ~25 km/s üzerinde varlık puanı birikmez (hem hile hem güvenlik için).
- Konum örnekleme aralığı ve doğruluk (accuracy) eşiği: doğruluğu kötü (>50 m) konumlar sayılmaz.
- Şüpheli hesaplar için sunucu tarafı puanlama (risk skoru), gerekirse geçici askıya alma.

---

## 6. Yapılar ve İşletme

| Seviye | Yapı | Yapım maliyeti* | Saatlik gelir* | Ziyaretçi kirası* | Yükseltme koşulu |
|---|---|---|---|---|---|
| 1 | ⛺ Çadır | 100 🪙 | 5 🪙/sa | 2 🪙 | Bölgeye sahip olmak |
| 2 | 🏠 Ev | 600 🪙 | 25 🪙/sa | 10 🪙 | Çadır + Oyuncu Sv. 5 |
| 3 | 🏨 Otel | 3.000 🪙 | 120 🪙/sa | 50 🪙 | Ev + Sv. 15 |
| 4 | 🏙️ Gökdelen | 15.000 🪙 | 500 🪙/sa | 200 🪙 | Otel + Sv. 30 |

\* Tahmini, dengeleme (balancing) sonrası değişecek.

### Gelir işleyişi
- Gelir **çevrimdışıyken de birikir** ama **depolama tavanı** vardır (ör. 8 saatlik gelir). Oyuncu uygulamaya girip **"topla"** butonuna basar. Bu, günlük dönüşü sağlar.
- Yapılar zamanla **bakım** ister (opsiyonel, V2): bakım yapılmazsa gelir düşer.

### Yapı özelleştirme (V2)
- Yapıya tema/görünüm kozmetiği (ör. pastel çatı, bahçe, bayrak).
- Komşu bölgeler aynı sahibindeyse **bitişik bonus** (ör. 3+ bitişik bölge → %10 gelir).

---

## 7. Kira Sistemi

- Bir oyuncu başka bir oyuncunun yapılı bölgesine girdiğinde (sunucu, konumdan H3 indeksini hesaplar) **kira** oluşur.
- Kira tutarı yapı seviyesine göre belirlenir (bkz. tablo).

### Dengeleme kuralları (oyunu bunaltıcı yapmamak için)
1. **Ziyaret başına bir kez:** Aynı bölgede aynı kişiye 1 saat içinde tekrar kira ödenmez (cooldown).
2. **Günlük kira tavanı:** Bir oyuncu günde en fazla X 🪙 kira öder (ör. gelirinin %30'u veya sabit tavan).
3. **Yeni oyuncu koruması:** İlk 3 gün veya ilk seviye(ler)de kira ödemez.
4. **Bakiye yetersizse:** Borç oluşmaz, sadece eldeki kadar ödenir (negatif bakiye yok).
5. **Arkadaş/klan muafiyeti:** Arkadaşlar arası kira yok veya indirimli (opsiyonel, sosyal bağ için).
6. **Kendi bölgende kira yok.**
7. **Bildirim:** "Ayşe'nin otelinde 50 🪙 kira ödedin" / "Mehmet bölgene girdi, 10 🪙 kazandın". Gönderim gruplanır, spam olmaz.

### Kira yerine alternatif (V2)
- Oyuncu kira ödemek yerine **hizmet satın alabilir** (ör. otelde "dinlen" → enerji/görev bonusu). Kira, bir "ziyaretçi deneyimine" dönüşür.

---

## 8. Karakter ve Kozmetik Sistemi

### 8.1 Karakter oluşturma
- İlk açılışta: isim, gövde tipi, ten rengi, saç, yüz, başlangıç kıyafeti seçimi.
- Karakter haritada küçük bir **avatar işaretçisi** olarak görünür; yürürken animasyon oynar (idle/walk).

### 8.2 Kozmetik kategorileri
Saç • Yüz/ifade • Üst giyim • Alt giyim • Ayakkabı • Şapka/aksesuar • Sırt çantası • Yürüme efekti (iz bırakan çiçek, kalp, yıldız) • Avatar çerçevesi • Harita işaretçisi (marker) stili • Bölge sınırı rengi/deseni • Yapı teması

### 8.3 Nadirlik
Yaygın → Nadir → Epik → Efsanevi. Sezon/etkinlik ürünleri **sınırlı süreli** olabilir.

### 8.4 Teknik yaklaşım (Öneri)
- Avatar **katmanlı 2D sprite** (her kozmetik ayrı PNG/SVG katman) veya Rive/Lottie animasyonu. 3D ilk sürüm için gereksiz maliyet.
- Kozmetik katalog verisi sunucuda JSON/tablo olarak tutulur; yeni ürün eklemek uygulama güncellemesi gerektirmemelidir.
- Envanter + "kuşan" (equip) durumu sunucuda saklanır.

### 8.5 Para birimleri
- 🪙 **Altın (Coin):** oyun içinden kazanılır; yapı, basit kozmetik.
- 💎 **Elmas (Gem):** premium; nadir kozmetik, hızlandırıcılar. Satın alınabilir ve nadiren görev/başarımdan kazanılabilir.
- **Gelir modeli (✅ Karar):** Kozmetik satışı + **isteğe bağlı ödüllü reklam**. Reklam yalnızca "bonus al" butonunun arkasındadır (küçük altın bonusu); haritada veya oyun akışında zorla reklam gösterilmez. 13+ kitle nedeniyle çocuklara uygun, kişiselleştirilmemiş reklam modu kullanılır.
- **Ödeme ilkesi:** Pay-to-win olmamalı. Elmas ile **kozmetik** ve **kolaylık** alınır; bölge ele geçirme gücü satılmaz.

---

## 9. Ek Özellik Fikirleri

**Keşif ve hareket**
- 🎯 **Günlük görevler:** "3 yeni bölgeyi ziyaret et", "2 km yürü", "Bir parkta 10 dk geçir".
- 📍 **İlgi noktası (POI) bonusu:** Park, kafe, müze, sahil gibi yerlerdeki bölgeler ekstra gelir/nadir kozmetik düşürür (OpenStreetMap verisi).
- 🌦️ **Hava durumu etkisi:** Yağmurda "şemsiye" bonusu, güneşli günde piknik bonusu. Dışarı çıkmayı teşvik eder.
- 🚶 **Adım sayacı entegrasyonu:** Adımlar küçük altın bonusu verir.

**Sosyal**
- 👫 **Arkadaş sistemi:** Arkadaşların bölgeleri haritada farklı gösterilir, kira muafiyeti.
- 🏘️ **Klan / Mahalle:** Klanlar ortak bölge havuzu, ortak hedef, klan sohbeti.
- 🏆 **Liderlik tabloları:** Şehir, semt, klan bazlı (en çok bölge, en çok gelir, en çok keşif).
- 🎁 **Hediye:** Arkadaşa kozmetik/altın gönderme.

**Uzun vadeli**
- 🗓️ **Sezonlar:** 2–3 aylık sezonlar, sezon ödülleri, özel kozmetikler.
- 🎉 **Etkinlikler:** Hafta sonu "çift gelir", bayram/özel gün temaları.
- 📜 **Başarımlar (achievements)** ve rozetler.
- 🧭 **Koleksiyon:** Şehirdeki belirli noktaları gez → koleksiyon tamamla.
- 🏛️ **Özel bina türleri (V3):** Kafe, park, müze → farklı fayda (ör. kafe = enerji, park = görev bonusu).
- 🤝 **Pazar yeri (V3):** Oyuncular arası bölge/kozmetik takası (dikkat: ekonomi ve hile riski yüksek).

---

## 10. Güvenlik, Gizlilik ve Yasal

### Oyuncu güvenliği
- Yürürken telefona bakmayı azaltan tasarım: ana etkileşimler **pasif**, bildirimler kısa.
- **Hız uyarısı:** Araçtayken "Güvenliğin için bu hızda oyun duraklatıldı."
- **Yasak / güvenli olmayan bölgeler:** Askeri alan, okul bahçeleri, hastane, özel mülk, otoyol, tehlikeli alanlar oyun dışı bırakılır (bölge "oynanamaz" işaretlenir).
- Gece oynama uyarıları, "tehlikeli yere girme" hatırlatması.

### 13+ hedef kitle sonuçları (✅ Karar: 13+)
- Serbest metin sohbeti **yok**; hazır mesajlar/emoji. Klan sohbeti kısıtlı veya moderasyonlu.
- Kesin konum kimseye gösterilmez; bu **varsayılan ve kapatılamaz** kural. Arkadaşlar bile sadece altıgen seviyesinde görür.
- Rastgele paket (loot box) yok; harcama limiti ve ebeveyn onayı akışı.
- Reklam ağında çocuklara uygun mod, kişiselleştirilmemiş reklam.
- Türkiye'de KVKK kapsamında 18 yaş altı veli onayı konusu **yayından önce bir hukukçuyla netleştirilmelidir.**

### Gizlilik (KVKK / GDPR)
- Ev adresi tahmin edilemesin: Oyuncunun **kesin konumu diğer oyunculara gösterilmez**. Sadece bölge (altıgen) seviyesinde yaklaşık konum, hatta isteğe bağlı "canlı konumumu gizle".
- Konum verisi **minimum süre** saklanır; ham konum kayıtları kısa sürede silinir/anonimleştirilir.
- Açık rıza metni, konum izni gerekçe ekranı, veri silme ve hesap silme akışı.
- 13/16 yaş altı için kısıtlamalar; ebeveyn onayı gereksinimi değerlendirilecek.
- Sohbet/kullanıcı adı için **moderasyon ve raporlama** sistemi.

### Mağaza gereklilikleri
- Apple/Google konum izni metinleri, arka plan konum kullanımı gerekçesi (Play/App Store incelemesinde sıkça reddedilme sebebi).
- Uygulama içi satın alma politikaları (loot box/rastgele paket kullanılacaksa olasılık açıklama zorunlulukları).

---

## 11. Pil ve Performans

- Arka planda konum: **düşük güç modu**, hareket algılama (yürüyor/duruyor) ile örnekleme sıklığı ayarlanır.
- Konum güncellemeleri sunucuya **toplu (batch)** gönderilir (ör. 30–60 sn aralık).
- Harita altıgenleri sadece görünür alan için istemciye çekilir; Realtime aboneliği yalnızca görünür bölgeye.
- Çevrimdışı/kötü internette konum kuyruğa alınır, sonra gönderilir.

---

## 12. Veri Modeli (Taslak)

```
users            (id, username, level, xp, coins, gems, created_at, ...)
characters       (user_id, body_type, skin, hair, face, ...)
cosmetics        (id, category, name, rarity, price_coin, price_gem, asset_url, season_id, limited_until)
user_cosmetics   (user_id, cosmetic_id, acquired_at)
user_equipped    (user_id, slot, cosmetic_id)

hexes            (h3_index PK, owner_id, claimed_at, last_visited_at, is_blocked, poi_type)
structures       (id, h3_index FK, type[tent|house|hotel|skyscraper], level, built_at, last_collected_at)
presence_log     (id, user_id, h3_index, seconds, recorded_at)      -- kısa süre saklanır
hex_progress     (user_id, h3_index, accumulated_seconds, window_start)

rent_events      (id, payer_id, owner_id, h3_index, amount, created_at)
transactions     (id, user_id, type, amount, currency, ref_id, created_at)   -- tüm para hareketleri

friendships      (user_id, friend_id, status)
clans            (id, name, ...)   clan_members (...)
quests           (id, type, goal, reward)   user_quests (...)
seasons          (id, name, starts_at, ends_at)
```

**İlke:** Her para hareketi `transactions` tablosuna yazılır (denetlenebilirlik ve hile tespiti). Bakiyeler sadece sunucu fonksiyonları ile değişir.

---

## 13. Servis / API Listesi (Taslak)

| Servis | Açıklama |
|---|---|
| `POST /location/ping` | İstemci konumunu gönderir; sunucu h3 hesaplar, presence günceller, sahiplik/kira tetikler |
| `GET /hexes?bbox=` | Görünür alandaki altıgenler |
| `POST /hex/claim` | Sahiplenme doğrulaması (sunucu kararı) |
| `POST /structure/build` / `upgrade` | İnşa / yükseltme |
| `POST /income/collect` | Biriken geliri topla |
| `GET /profile`, `POST /character/equip` | Profil ve kozmetik kuşanma |
| `GET /shop`, `POST /shop/purchase` | Mağaza |
| `GET /quests`, `POST /quests/claim` | Görevler |
| `GET /leaderboard` | Sıralamalar |
| Realtime kanalları | Kira/bölge değişim bildirimleri |

---

## 14. Tasarım Sistemi — Tatlı ve Ferah

### Renk paleti
| Rol | Renk | Hex |
|---|---|---|
| Arka plan | Krem beyaz | `#FFFBF5` |
| Birincil | Nane yeşili | `#7ED9B5` |
| İkincil | Gökyüzü mavisi | `#8EC9F5` |
| Vurgu 1 | Şeftali | `#FFC9A8` |
| Vurgu 2 | Lavanta | `#C9B8F5` |
| Vurgu 3 | Tereyağı sarısı | `#FFE9A3` |
| Uyarı / kira | Pudra pembe | `#FFABB8` |
| Metin | Koyu deniz grisi | `#2F3E46` |
| İkincil metin | Yumuşak gri | `#7A8A93` |

- Oyuncu bölge renkleri, yukarıdaki pastel tonlardan atanır (her oyuncuya benzersiz/ayırt edilebilir).
- Harita stili: açık, az detaylı, su = açık mavi, park = açık nane, yollar = krem/beyaz.

### UI ilkeleri
- **Yuvarlak köşeler** (16–24 px), yumuşak gölgeler, kabarcık (bubble) hissi.
- Yuvarlak, dost tipografi (öneri: **Nunito** veya **Quicksand**).
- Mikro animasyonlar: altın toplama sıçraması, yapı dikilirken "pop" efekti, bölge sahiplenirken dolgu animasyonu, konfeti.
- Ses: yumuşak, kısa, rahatsız etmeyen efektler; müzik isteğe bağlı.
- İkonlar: tutarlı, dolgulu ve yuvarlak hatlı set.
- Erişilebilirlik: renk körlüğü için bölgeler sadece renkle değil **desen/ikon** ile de ayırt edilebilmeli; yeterli kontrast.

### Temel ekranlar
1. Açılış / giriş
2. Karakter oluşturma
3. **Ana harita** (altıgenler, avatar, altın topla butonu, görev şeridi)
4. Bölge detayı (sahibi, yapı, kira, geliştir)
5. İnşa / yükseltme
6. Karakter & gardırop
7. Mağaza
8. Görevler ve başarımlar
9. Sosyal (arkadaşlar, klan, sıralama)
10. Profil ve ayarlar (gizlilik dahil)

---

## 14.1 Görsellik, Hafif 3D His ve Tatmin Animasyonları

**Hedef:** Oyuncu bir bölgeyi aldığında ve bir yapı diktiğinde *"oh, tatmin oldum"* hissi yaşamalı. Bu, oyunun en önemli duygusudur; bu yüzden bu anlara özel zaman ayrılır.

### A) Hafif 3D his nasıl sağlanır (Öneri: A yolu)
| Yol | Nasıl | Artı | Eksi |
|---|---|---|---|
| **A) 2.5D (önerilen)** | Harita eğimli (pitch ~45–55°), altıgenler yükseltilmiş (extrusion) bloklar, yapılar izometrik illüstrasyon sprite'ları + yumuşak gölge | Hafif, düşük telefonlarda çalışır, tatlı görünür | Gerçek 3D model kadar derin değil |
| B) Gerçek 3D | glTF 3D modeller, 3D motor | Çok etkileyici | Ağır, pil ve performans maliyeti, üretim maliyeti yüksek |

**A yolunun ayrıntıları**
- Kamera eğimi 45–55°, kullanıcı haritayı döndürebilir (bearing). Dönerken sprite'lar hafifçe yön değiştirir.
- Sahipli altıgenler sahibinin pastel renginde **yükseltilmiş blok** gibi görünür; yükseklik yapı seviyesine göre artar (sahipsiz 0, çadır düşük, gökdelen en yüksek).
- Her yapının altında yumuşak **gölge (blob shadow)**; ışık hep sol üstten gelir (tutarlılık).
- Hafif parallax ve kenarlarda ince aydınlık çizgi ile "oyuncak blok" hissi.
- Avatar, haritada ayakta duran küçük bir karakter (billboard), altında gölgesi ile.
- **Adım 0.5 bir deneme (spike)'dir:** Bu teknik Flutter + MapLibre'de çalışmazsa yedek plan: altıgenler düz çizilir, yükseklik hissi sprite ve gölgelerle verilir.

### B) Bölge sahiplenme anı (claim) — hissiyat tarifi
1. **Bölgede beklerken:** Altıgenin zemini aşağıdan yukarı yumuşakça dolar (ilerleme), avatarın etrafında hafif parıltı. Sayaç küçük ve sakin.
2. **Tamamlanma anı:** Orta şiddetli haptik titreşim + kısa "tık/ding" sesi.
3. **0–400 ms:** Altıgen sahibinin rengine **merkezden dışa doğru dalga** ile dolar, blok yerden **elastik (overshoot'lu)** şekilde yükselir.
4. **200–700 ms:** Komşu altıgenlerde hafif dalgalanma (ripple) halkası yayılır.
5. **300–900 ms:** Yıldız/parıltı parçacıkları, "+1 Bölge" ve "+XP" yazısı yukarı süzülür.
6. **Özel anlar** (ilk bölge, 10. bölge, bitişik 3 bölge): konfeti ve daha büyük kutlama.

### C) Yapı inşası — hissiyat tarifi
- **Çadır:** Zeminde işaret → küçük toz bulutu → çadır **squash & stretch** ile zıplayarak belirir (0 → %110 → %100) → küçük parıltı.
- **Ev / Otel:** Hafif iskele hissi → yapı aşağıdan yükselir → kapı/pencere ışıkları "yanar" → çatı tepeden oturur.
- **Gökdelen:** Katlar **tek tek üst üste** dizilir (her kat ~120 ms), kamera hafifçe yukarı kayar, tepeye bayrak dikilir, hafif ekran titremesi.
- **Yükseltme (ör. Çadır → Ev):** "Puf" duman bulutu → eski yapı küçülür → yenisi büyür → sikke yağmuru.
- **İnşa bitişi:** Gelen altın, sayaçta sıçrayarak birikir ("kasa" hissi), haptik + ses.
- **Gelir toplama:** Yapıdan sikkeler çıkıp üst sayaca **uçar**, sayaç hızlıca sayar. Bu tatmin hissinin en kritik anlarından biri.

### D) Animasyon kuralları
- Rutin animasyonlar **≤ 1,5 sn**; büyük anlar (gökdelen, ilk bölge) biraz daha uzun olabilir.
- **Her animasyon atlanabilir** (dokununca hızlanır/biter). Oyuncuyu bekletme.
- UI'yı bloklama: animasyon sırasında harita ve butonlar çalışmaya devam eder.
- Ayarlarda **"Hareketi azalt"** ve **"Ses / titreşim"** anahtarları.
- Düşük donanım tespitinde yedek mod: daha az parçacık, basit animasyon.
- Performans hedefi: orta segment Android'de akıcı (yaklaşık 60 fps hedef, 30 fps altına düşmemeli).
- Ses: yumuşak, kısa, sinir bozmayan; her olay için 1 ses, tekrarlayınca hafifçe ton değiştir (monotonluk olmasın).
- Bütün animasyon süre/şiddet değerleri **config**'te olsun; ince ayar kod değişikliği istemesin.

---

## 15. Geliştirme Aşamaları

### 🟢 Faz 0 — Hazırlık (1 hafta) — *Platform: önce Android*
- [ ] Oyun adı, kısa tasarım notu, bu MD'nin netleştirilmesi
- [ ] Flutter projesi, klasör yapısı, lint kuralları, CI
- [ ] Supabase projesi, ortamlar (dev/prod)
- [ ] MapLibre/Mapbox hesabı ve pastel stil taslağı
- [ ] H3 entegrasyon denemesi (konum → altıgen çizimi)

### 🟢 Faz 1 — Çekirdek Prototip (2–3 hafta)
- [ ] Giriş (e-posta / Google / Apple) — Google ile giriş Adım 0.7'de yapılır, kapalı beta öncesi tamamlanmalı
- [ ] Konum izni akışı ve arka plan konum takibi
- [ ] Haritada kullanıcının konumu ve altıgenlerin çizimi
- [ ] `location/ping` servisi, presence birikimi, bölge sahiplenme
- [ ] Sahip olunan bölgelerin renkle gösterimi
- [ ] Hafif 3D görünüm (eğimli kamera, yükseltilmiş altıgenler) — Adım 0.5 sonucuna göre
- [ ] Bölge sahiplenme animasyonu (bölüm 14.1-B), haptik ve ses
- [ ] Temel hile kontrolleri (hız, doğruluk)
- [x] Yürüyüş modu (Adım 1.6) — kod hazır, cihaz testi bekliyor

### 🟡 Faz 2 — Ekonomi ve Yapılar (2–3 hafta)
- [x] Altın bakiyesi, `transactions` altyapısı (Adım 2.1)
- [ ] Çadır → Ev → Otel → Gökdelen inşa/yükseltme
- [ ] Yapı inşa ve yükseltme animasyonları (bölüm 14.1-C)
- [ ] Gelir toplama animasyonu (sikkeler sayaca uçar)
- [ ] Gelir birikimi ve "topla" akışı
- [ ] Kira mekaniği (cooldown, tavan, yeni oyuncu koruması)
- [ ] Push bildirimleri (kira, gelir dolu)

### 🟡 Faz 3 — Karakter ve Kozmetik (2–3 hafta)
- [ ] Karakter oluşturucu, katmanlı avatar sistemi
- [ ] Kozmetik kataloğu, envanter, kuşanma
- [ ] Mağaza (Altın ile), harita işaretçisi avatarı
- [ ] İlk kozmetik seti (yaklaşık 30–40 parça)

### 🟠 Faz 4 — Sosyal ve Retention (3 hafta)
- [ ] Günlük görevler, seviye/XP, başarımlar
- [ ] Arkadaşlar, liderlik tabloları
- [ ] POI bonusları, hava durumu etkisi (opsiyonel)
- [ ] Onboarding / öğretici (ilk 5 dakika deneyimi)

### 🟠 Faz 5 — Monetizasyon ve Cilalama (2–3 hafta)
- [ ] Elmas (Gem) ve uygulama içi satın alma (RevenueCat)
- [ ] Premium kozmetikler, sezon pası (opsiyonel)
- [ ] Performans/pil optimizasyonu, animasyonlar, ses
- [ ] Gizlilik ayarları, KVKK metinleri, hesap silme

### 🔴 Faz 6 — Beta ve Yayın
- [ ] Kapalı beta (TestFlight / Play Internal Testing) — tek bir şehir/semtte başla
- [ ] Ekonomi dengeleme (veriye göre fiyat/gelir ayarı)
- [ ] Mağaza incelemesi hazırlığı (konum izni gerekçeleri, ekran görüntüleri)
- [ ] Yumuşak lansman (tek şehir) → genişleme

### 🔵 Faz 7+ — Gelecek
- Klanlar, özel binalar, pazar yeri, sezonlar, etkinlikler, yeni şehirler

---

## 16. Önerilen Klasör Yapısı (Flutter)

```
lib/
  core/            # tema, router, config, sabitler, yardımcılar
  data/            # repository'ler, Supabase istemcisi, modeller
  features/
    auth/
    map/           # harita, h3 katmanı, konum servisi
    hex/           # bölge detayı, sahiplik
    structures/    # inşa, yükseltme, gelir
    rent/
    character/     # avatar, gardırop
    shop/
    quests/
    social/
    profile/
  shared/          # ortak widget'lar (butonlar, kartlar, animasyonlar)
supabase/
  migrations/      # SQL şeması
  functions/       # edge function'lar (ping, claim, build, collect, purchase)
docs/
  PROJE_PLANI.md
  LESSONS.md       # öğrenme günlüğü (hata ve iyi şeyler)
  DECISIONS.md     # agent'ın aldığı küçük kararlar
  ECONOMY.md       # denge tabloları (ileride)
CLAUDE.md          # kısa agent talimatı (repo kökünde)
```

---

## 17. Antigravity (Agent) İçin Çalışma Kuralları

> Bu kuralların kısa hali repo kökündeki `CLAUDE.md` içindedir. Agent her oturumda **önce onu**, sonra `docs/LESSONS.md` > "Altın Kurallar" bölümünü okur. Bu planın tamamı değil, **yalnızca ilgili bölüm** okunur (token tasarrufu).

### Adım adım ilerleme ve token tasarrufu
1. **Bir oturum = bir adım.** Adımlar bölüm 19'da listelidir. Adım bitince agent durur, kullanıcı onaylayınca sonraki adıma geçilir.
2. Kodlamadan önce en fazla 5 satırlık plan, sonra uygulama. Uzun açıklama yok.
3. Dosyayı baştan yazmak yerine **hedefli düzenleme**. Büyük çıktıları sohbete yapıştırma.
4. Sadece değişen yeri doğrula; gereksiz tam derleme/test yok.
5. Adım sonunda en fazla 5 satırlık özet: ne yapıldı, nasıl denenir, sıradaki adım.
6. Her adım sonunda git commit (`adim-X.Y: ...`).

### Öğrenme döngüsü
- Adım başı: `LESSONS.md` > Altın Kurallar'ı oku.
- Adım sonu: Günlüğe kısa giriş ekle (✅ iyi giden / ❌ hata ve çözümü / 📌 çıkarılan kural).
- Aynı şey iki kez yaşanırsa Altın Kurallar'a taşı.
- Doğrulanmamış bilgiyi "doğrulandı" diye yazma.

### Teknik kurallar
1. **Sunucu otoritesi:** Para, sahiplik, kira ve sahiplenme mantığı asla istemcide karara bağlanmaz.
2. **Config odaklı:** Fiyat, süre, tavan, gelir, animasyon süreleri config'ten okunur.
3. **Test:** Mekanikler (sahiplenme süresi, kira cooldown, gelir) için birim testi.
4. **Tema:** Renk ve tipografi sadece `core/theme`'den.
5. **Gizlilik:** Kesin koordinat diğer oyunculara dönen yanıtlarda yer almaz.
6. **Güvenlik:** Gizli anahtarlar repoya yazılmaz; RLS tüm tablolarda açık.
7. **Animasyon:** Bölüm 14.1-D kurallarına uy (atlanabilir, bloklamaz, yedek mod).
8. **Belirsizlik:** Küçük kararlarda varsayım yap ve `docs/DECISIONS.md`'ye yaz; büyük kararlarda kullanıcıya tek soru sor.

### İlk görev için hazır komut (Antigravity'e yapıştır)
> `CLAUDE.md` dosyasını oku, sonra `docs/LESSONS.md` içindeki "Altın Kurallar" bölümünü oku. Şimdi sadece **Adım 0.1**'i yap (`docs/PROJE_PLANI.md` bölüm 19). Bitince 5 satırlık özet ver, LESSONS.md'ye giriş ekle, commit at ve dur. Sonraki adıma ben söyleyince geçeceğiz.

---

## 18. Verilen Kararlar

| # | Konu | Karar |
|---|---|---|
| 1 | Oyun adı | **Catch Me** (maskot henüz belirlenmedi) |
| 2 | Altıgen boyutu | **Res 9** (~174 m, mahalle ölçeği) |
| 3 | Başlangıç bölgesi | **Tek şehir** ile başla (şehir seçimi bekliyor, öneri: Kayseri) |
| 4 | Gelir modeli | **Kozmetik + isteğe bağlı ödüllü reklam** |
| 5 | Yapısız bölge devralma | **Devralınabilir** (toplam 30 dk) |
| 6 | Hedef kitle | **13+** (geniş kitle) |
| 7 | Platform önceliği | **Android önce**, iOS sonra |

### Hâlâ açık olanlar
- Maskot (hayvan/bulut?) ve karakter stili
- Başlangıç şehri kesinleştirme
- 13+ için yasal danışmanlık (KVKK veli onayı)

---

## 19. Mikro Adım Listesi (Her biri tek oturumluk)

Her adımın "bitti sayılır" ölçütü vardır. Agent o ölçüt sağlanınca durur.

### Faz 0 — Hazırlık
| Adım | İş | Bitti sayılır |
|---|---|---|
| 0.1 | Flutter projesi, klasör yapısı (bölüm 16), boş ekranlar, `CLAUDE.md` ve `docs/` yerleşimi | Uygulama Android'de açılıyor, klasörler hazır |
| 0.2 | Pastel tema (`core/theme`, renkler, Nunito, buton/kart stilleri) | Tema örnek ekranında palet ve bileşenler görünüyor |
| 0.3 | Harita ekranı (MapLibre, pastel stil) + konum izni (sadece ön plan) | Harita açılıyor, kullanıcı konumu görünüyor |
| 0.4 | H3 entegrasyonu: konum etrafındaki altıgenleri düz çiz | Konumun çevresinde Res 9 altıgenler çiziliyor |
| **0.5** | **3D deneme (spike):** eğimli kamera, altıgeni yükseltme (extrusion), tek altıgende yükselme animasyonu, performans ölçümü | Çalışıyor mu / FPS nedir kararı `DECISIONS.md`'de. Çalışmazsa yedek plan seçilir |
| 0.6 | Supabase projesi, giriş (auth), `users` tablosu, RLS | Giriş yapılıyor, RLS test edildi |
| 0.7 | Google ile giriş: Google Cloud Console'da OAuth kurulumu, Android SHA-1 parmak izinin tanıtılması, Supabase'de Google sağlayıcısının açılması, giriş ekranına "Google ile devam et" butonu | Telefonda Google hesabıyla giriş yapılıp çıkılabiliyor, e-posta girişi de çalışmaya devam ediyor |

### Faz 1 — Çekirdek
| Adım | İş | Bitti sayılır |
|---|---|---|
| 1.1 | `location/ping` servisi (h3 hesabı, hız/doğruluk filtresi) | Konum gönderilince sunucu doğru altıgeni buluyor |
| 1.2 | Presence birikimi ve sahiplenme (10 dk toplam) | Süre dolunca bölge kullanıcıya geçiyor |
| 1.3 | Sahiplenme animasyonu (bölüm 14.1-B), haptik, ses | Claim anı tarif edilen sırayla oynuyor, atlanabiliyor |
| 1.4 | Sahipli altıgenlerin renkli/yükseltilmiş çizimi | Kendi ve başkasının bölgeleri farklı renkte görünüyor |
| 1.5 | Temel hile kontrolleri (mock location, hız) | Sahte/hızlı konum reddediliyor |
| 1.6 | Yürüyüş modu: "Yürüyüşe başla" butonu, foreground service ve kalıcı bildirim ("Catch Me aktif"), ekran kapalıyken konum takibi, hız 25 km/s üstünde otomatik duraklama, açık/kapalı durum göstergesi | Telefon cepte ve ekran kapalıyken 10 dk yürüyüşte presence birikiyor, bildirim görünüyor, durdurunca takip bitiyor |

### Faz 2 — Ekonomi ve Yapılar
| Adım | İş | Bitti sayılır |
|---|---|---|
| 2.1 | Altın bakiyesi + `transactions` | Tüm para hareketleri kayıtlı |
| 2.2 | Çadır inşası + inşa animasyonu. Hücrede `level` alanı (1 = çadır); yapı tipi seviyeden türer, yükseltme kaynağı altın | Çadır dikilirken animasyon oynuyor, bakiye düşüyor |
| 2.3 | Gelir birikimi ve "topla" (sikkeler sayaca uçar). Gelir çarpanı `level`'e göre config'ten | Gelir toplanıyor, animasyon çalışıyor |
| 2.4 | Ev / Otel / Gökdelen + yükseltme animasyonları (seviye 2–4, altınla; ileride GP ile de) | Dört seviye de inşa/yükseltilebiliyor |
| 2.5 | Kira mekaniği (cooldown, tavan, yeni oyuncu koruması) | Başkasının bölgesine girince kira işliyor |

### Mini oyun fazı (TASLAK: M.0 prototipi sevilirse uygulanır)
Karar ayrıntıları: `docs/DECISIONS.md` → "Mini oyun ve seviye sistemi". Numaralar Faz 3 ile çakışmasın diye `M` önekli; Faz 2 sırasından bağımsız, 2.1–2.5 mini oyuna bağlı değil (yalnızca `level` alanı ortak).
| Adım | İş | Bitti sayılır |
|---|---|---|
| M.0 | Hex Merge prototipi (projeden bağımsız tek sayfa): birleşme kuralı, karo olasılığı, tahta boyutu, combo ve "bir tur daha" hissi denenir | Kullanıcı oynayıp oyunu sevdiğini ve kuralları onayladığını söylüyor; kurallar kısa bir kural belgesine yazılıyor |
| M.1 | Dart motoru: tahta, birleşme, skor, seed'li PRNG (UI yok) + birim testleri | `flutter test` geçiyor |
| M.2 | TypeScript motoru (Edge Function için) + ortak altın replay test vektörleri | Aynı replay Dart ve TS'te aynı skoru veriyor; yerelde Deno/Node ile çalışıyor |
| M.3 | Tahta ekranı (`CustomPainter`, tema, haptik/ses/partikül, yedek mod) + antrenman modu (sunucusuz) | Cihazda oynanıyor, akıcı, atlanabilir animasyonlar |
| M.4 | `challenge_sessions`, `hex_scores`, GP/seviye; `start_challenge`, `submit_develop` (kendi hücre, GP), `submit_challenge` (devralma); harita hücre kartı (Oyna / Meydan oku) | Kendi hücrede GP ile seviye atlıyor; başkasının hücresinde skoru geçince devralma + animasyon; sahte skor reddediliyor |
| M.5 | Savunma skoru aşınması, koruma penceresi, rövanş, kayıp bildirimi, devralmada seviye düşüşü | Elle zaman kaydırarak her kural doğrulanıyor |

*Faz 3 ve sonrası adımları, Faz 2 bitince birlikte yazarız (plan o zamana kadar değişebilir).*

---

*Son güncelleme: 8 Ekim 2026 — Sürüm 0.4 (mini oyun fazı taslağı, seviye = yapı kararı eklendi)*
