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

## Mini oyun ve seviye sistemi (tasarım kararı, 2026-10-08; kod yok)
Durum: **taslak, oyun prototipte sevilirse uygulanır** (PROJE_PLANI "Mini oyun fazı", M.0–M.5). Prototip sevilmezse bu bölümün sadece "Seviye = yapı" kısmı geçerli kalır.
- **Hibrit sahiplenme:** Sahipsiz hücre = kısa presence ile claim (mevcut mekanik, süre config). Başkasının hücresi = skorlu **meydan okuma** (sahibin savunma skorunu geçen devralır, beraberlikte sahip). Kendi hücre = **sınırsız "Geliştirme"** oyunu. Zamanı beklemek çekirdek mekanik olmaktan çıkar, sadece pasif gelir kalır.
- **Mini oyun: Hex Merge.** 19 hücreli (yarıçap 2) altıgen tahta, sıradaki karo seed'den gelir, bağlı aynı sayılar birleşir, zincir/combo çarpanı, tahta dolunca biter. Skor combo ve süre etkenlerini zaten içerir. Replay = sadece hücre indeksi listesi. Birleşme kuralı (2+ bağlı mı, 3+ mı) prototipte denenip seçilecek.
- **Adil seed:** Aynı hücre + aynı gün = aynı seed (sunucudan). İkinci denemede öğrenme/ustalık hissi.
- **Sunucu doğrulaması:** Skor istemciden güvenilmez; `submit` motoru TypeScript (Edge Function) ile yeniden oynatır, oturum süresi/minimum hamle süresi/skor tavanı ve "hâlâ o hücrede mi" (`ping_state`) kontrol edilir. Şüpheli skor 1.5'teki ihlal sistemine bağlanır. Motor Dart + TS iki dilde: PRNG elle tanımlı ve 32-bit maskeli, ortak "altın" replay test vektörleriyle parite doğrulanır. Yerelde Deno yok (LESSONS) → M.2'de çözülmeli.
- **Seviye = yapı:** Hücrede tek `level` alanı; seviye 1 çadır, 2 ev, 3 otel, 4 gökdelen (yapı tipi seviyeden türer, eşikler/gelir çarpanı config). **Yükseltme kaynağı şimdilik altın** (2.2/2.4); mini oyun onaylanırsa **GP ile ikinci yol** eklenir, aynı `level` alanını artırır, hiçbir şey sökülmez.
- **GP (Gelişim Puanı):** Sadece oyun skorundan (ek bonus yok). Günlük yumuşak tavan: ilk N oyun tam GP, sonrası azalan (config). Kaybeden oyun da az GP verir. Sadece sunucuda doğrulanmış oyun GP verir.
- **Seviye düşmez; devralmada bir miktar düşer, "çok değil"** (ör. bir kademe veya %20–25; oran config). Seviye üst sınırı **açık**, sonra karar verilecek.
- **Savunma skoru ≠ seviye:** Savunma skoru günlük en iyi skor ve zamanla **aşınır** (config); seviye kalıcı gelişimi gösterir. Devralma sonrası yeni sahibe kısa koruma penceresi, eski sahibe rövanş denemesi.
- **Meydan okuma sıklığı:** Hak yerine soğuma süresi (art arda başarısızlıkta); yeni hücreye girince ek deneme. Kendi hücrede sınır yok. Ev sahibi avantajı bilinçli.
- **Güvenlik/etik:** Mini oyun sadece hız eşiğinin altında açılır (13+ kitle, yürürken ekran bakmayı teşvik yok). Sahte aciliyet, "devam için öde" baskısı yok. Uzun oturumda hafif mola hatırlatması düşünülebilir.
- **Gizlilik:** Diğer oyunculara sadece skor ve takma ad döner, koordinat asla.
- **Antrenman modu:** Konum gerekmez, ödül yok; tutorial olarak da kullanılır.
- **Açık kalanlar:** Seviye üst sınırı, GP/skor oranı, seviye eşikleri, aşınma yüzdesi, günlük tavan sayıları, birleşme kuralı. Oyun oynanabilir olunca ayarlanır.
- **Fikir olarak park edildi (kapsam dışı):** Res 8 "semt" katmanı (semt kralı/haftalık sezon), mutatörler (aynı motorda varyasyon), bölge savunma (asenkron PvP) oyunu, takım/kulüp.

## Sonraya kalanlar (bölüm 19 listesi bitince ele alınacak)
- **Devralma (PROJE_PLANI 5.3):** *(Çözüm yönü: skorlu meydan okuma, yukarıdaki "Mini oyun ve seviye sistemi", PROJE_PLANI M.4.)* Bölüm 19'da hiçbir adıma bağlı değil. `accrue_presence` sahipli bölgede süreyi biriktiriyor ama devralma yapmıyor (`owned_by_other`). Temel mekanik; ayrı adım olarak eklenmeli (yürüyüş modu 1.6'dan sonra test edilebilir). Uyarı ve kayıp bildirimleri de bu kapsamda.
- **Bölge el değiştirme animasyonu:** Sahip değişince (kaybetme/devralma) renk sessizce güncelleniyor; bölüm 14.1'de tarifi yok. Cila turunda tasarlanacak.
- **Yürüyüşü otomatik başlatma (ayar):** Uygulama ön plana gelince yürüyüş modu kendiliğinden başlayabilir, ama **varsayılan kapalı bir ayar**; ilk açılışta açık rıza ekranında (PROJE_PLANI bölüm 8) oyuncuya sorulur. Düğme kalır (elle başlat/durdur). Android foreground service'i arka plandayken başlatamaz, bu yüzden "otomatik" = uygulama açılınca. Rıza ekranı adımıyla birlikte yapılacak; o zamana kadar sadece düğme (1.6).
- **Bölgelerime git (cila):** Haritada kendi bölgelerine uçan buton (önceki/sonraki ile gezinme). Uzaktayken bölgeyi elle aramak zor. Ek: kendi bölgelerim (en fazla `max_owned_hexes`) uzak zoom'da da çizilebilir; şu an >600 görünür hücrede (eğik kamerada yaklaşık zoom 13 altı) hiç sahiplik çizilmiyor.
- **Uzaktan bölge görünmeme raporu (Adım 1.5 testi sırasında):** Kullanıcı başka yerdeyken yakınlaştırdığı halde bölgesini görmedi. Kod incelemesinde bariz hata yok (görünür alan sorgusu konumdan bağımsız); olası sebepler: 600 hücre sınırı (eğik kamera görünür alanı büyütüyor), sahte konum testi sırasında kameranın yanlış yerde olması. Cihazda yeniden denenip doğrulanacak. **✅ 2026-10-09 cihazda doğrulandı: yakınlaştırınca görünüyor.**

## Adım 2.2 (çadır)
- **Uzaktan inşa serbest:** Oyuncu kendi hücresine o hücrede durmadan da çadır kurabilir (haritada hücreye dokun → kart). Plan aksini söylemiyor; konum şartı gerekirse `build_structure`'a eklenir.
- **Yapı = `hexes.level`** (ayrı `structures` tablosu yok, plan 2.2 böyle diyor). Tip seviyeden türer: 1 çadır, 2 ev, 3 otel, 4 gökdelen.
- **Çadır görseli 3D geometri** (fill-extrusion parçaları), sprite değil: bloğun üstüne oturur ve zoom'la ölçeklenir. Ölçü/renk oranları `GameConfig`'te.
- **Test altını:** Altın kazanma yolu (2.3 gelir) gelene kadar `supabase/tests/grant_test_coins.sql` ile elle verilir (`dev_grant` kaydı). İstemciye altın üreten RPC açılmadı.
- **Blok yüksekliği** şimdilik seviyeden bağımsız (40 m); plan 14.1-A "seviyeyle artar" diyor, 2.4'te ele alınacak.
- **Çadır dokusu ertelendi:** `fill-extrusion-pattern` ile kanvas/tahta dokusu mümkün (renk+desen aynı parçada olmaz), sprite daha gerçekçi ama 3D'ye oturmaz. Kullanıcı mevcut düz renkli görünümü onayladı; cila turunda tekrar bakılabilir.

## Adım 2.3 (gelir)
- **Topla = tüm yapılar birden** (sayacın altındaki çip). Hücre başı toplama yok; kartta sadece kasa bilgisi. Sikkeler ekrandaki yapılardan uçar, ekranda yapı yoksa çipten.
- **Konum şartı yok:** Gelir her yerden toplanır (günlük dönüş için).
- **Tavan aşınca fazlası yanar**; sayaç toplama anına çekilir. Kesirli gelir korunur.
- **Kasa periyodik okunur** (`incomePollSec` = 60 sn), istemci kendisi saymaz; oran/tavan sadece sunucu config'inde.
- **Sahiplenme süresi 5 dk** (`claim_seconds` = 300, önce 600). Test ve başlangıç hızı için; 5 bölge limiti ve devralma olmadığı için dengeyi bozmuyor. Devralma (30 dk) gelince dengeleme turunda birlikte ayarlanacak. Kayıt: `20261009030000_claim_5min.sql`.
- **Sahiplenme süresi 3 dk** (`claim_seconds` = 180, 2026-10-09): 5 dk sahada fazla geldi. Altıgenin (~350–400 m) ortasından yavaş geçiş veya kısa mola yeter, yanından geçmek yetmez. Kayıt: `20261009050000_claim_3min.sql`.

## GPS doğruluğu iyileştirme (2026-10-09, yürüyüş testi sonrası)
- **İstemci:** Konum 3 sn'de bir okunur (`walkFixIntervalSec`, `LocationAccuracy.best`); 15 sn ping penceresindeki en iyi okuma gönderilir (yeni okuma ≤%20 kötüyse yeniyi tercih eder, yürürken eski altıgende kalmasın). `walkMaxSendAccuracyM` (100 m) üstü veya 30 sn'den eski okuma **gönderilmez**; durum satırı "GPS sinyali zayıf, bekleniyor" der, iyi okuma gelince hemen gönderir.
- **Sunucu:** 50 m (`ping_max_accuracy_m`) – 100 m (`ping_soft_max_accuracy_m`) arası doğruluk, doğruluk dairesi tamamen tek altıgenin içindeyse kabul (hangi altıgen olduğu kesin). Üstü ret. Kayıt: `20261009040000_gps_soft_accuracy.sql`.
- **Süre kaybı:** Ret edilen ping `ping_state`'i güncellemediği için sonraki kabul edilen ping aradaki süreyi `presence_max_credit_s` (60 sn) tavanına kadar sayar; kısa zayıf sinyal anları süre kaybettirmez.

## Adım 2.4 (ev / otel / gökdelen)
- **Yükseltme = aynı RPC:** `build_structure` her çağrıda bir üst seviyeyi kurar (0→1→…→`max_structure_level`=4). Fiyat `build_cost_<seviye>`, gelir `income_per_hour_<seviye>` (plan tablosu: 600/3000/15000, 25/120/500).
- **Yükseltmede eski kasa otomatik toplanır** (`income` kaydı, ref = hücre) ve sayaç sıfırlanır: yeni oran geriye dönük işlemez, birikmiş gelir de yanmaz. Kasa yükseltme parasına sayılır (kart da bakiye + kasa ile karşılaştırır).
- **Oyuncu seviyesi şartı (Sv. 5/15/30) şimdilik yok:** oyuncu seviyesi sistemi henüz yok; o gelince `build_structure`'a eklenir.
- **Blok yüksekliği seviyeyle artmıyor** (40 m sabit): yükseklik hissini yapının kendisi veriyor (gökdelen ~1.2 r). 14.1-A'daki "blok seviyeyle yükselir" cila turunda tekrar değerlendirilebilir; değişirse tüm yapı katmanları blok yüksekliğini özellikten okumalı.
- **Kurulum animasyonu tek ifadeyle:** her parçada gecikme/süre/büyüme/oturma özelliği (`extrusionFeature`), animasyon katmanına karede tek `setLayerProperties`. Gökdelende "hafif ekran titremesi" yok (harita native görünüm; titreşim haptikle veriliyor), kamera yükselmesi yerine daha uzak odak zoom'u.
- **Görsel tur 1 (kullanıcı geri bildirimi):** Tarz aynı (düz renkli fill-extrusion), daha canlı palet (`AppColors` 2.4 bloğu) ve seviye seviye zenginleşen tasarım: ev = bahçeli modern ev (mercan iki tonlu çatı, ahşap kanat, cam vitrin, çalılar); otel = havuzlu resort (cam lobi, mor/pembe balkonlar, palmiyeler, çatı havuzu); gökdelen = kademeli cam kule (yukarı açılan cam tonları, nane köşe şeritleri, ışıklı taç, ikaz ışığı, ağaçlı meydan + fıskiye).
- **Bayraklar** çadırdaki gibi dünyada hep doğuya (sağa) uzanır, yapı yönünden bağımsız.
- **Gölge:** her parçanın taban+tavan köşeleri yansıtılıp zarfı alınır (kademeler, çatı, bayrak ayrı), altıgen bloğa kırpılır (`HexFrame.clip`), çadırda da. Katmanlı fill-extrusion tek seferde birleştiği için üst üste binen gölgeler koyulaşmaz. Kurulan yapının gölgesi animasyon bitince belirir.
- **Kademeli final:** ev = sikke yağmuru + başlık; otel = + şok dalgası + konfeti + claim tınısı; gökdelen = + havai fişek + ışık huzmesi + parlama + 3 katta bir titreşim. Süreler 2.3 / 2.9 / 4.2 sn (büyük an kuralı), sayılar `GameConfig.finale*`. Harita kamerası animasyonda oynatılmıyor (efekt konumları sabit kalsın).
- **Ses turu (kullanıcı geri bildirimi):** Toplama sesi klasik sikke ("bi-ding") dökülmesi. Yükseltmede tek sürekli iz (`upgrade_<seviye>.wav`), animasyon zamanlamasına göre sentezlenir (`tools/make_upgrade_sounds.py`, Do majör): puf → kurulum notaları → final; gökdelende her kat yükselen nota + riser, finalde darbe + fanfar + havai fişek çıtırtısı. Atlanınca iz kesilir, sadece `finale_<seviye>.wav` çalar. **Süre, kat sayısı veya parça gecikmesi değişirse sesler yeniden üretilmeli.** `make_collect_sound.py` kaldırıldı (collect.wav da yeni araçta).
- **Gökdelen v2:** Pahlı (sekizgen) katlar, 4 kademe 24 kat, iki katlı podyum, kademe aralarında lavanta "gökyüzü lobisi", daralan taç + iğne kule. Sarı taç kaldırıldı. Köşe sütunları yerine kat kat pah şeritleri (sütun tepesi ile bant/kademe yüzeyleri üst üste binip titriyordu).
