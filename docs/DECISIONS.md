# Küçük Kararlar (agent notları)

- **Adım 0.1:** `flutter create --project-name catch_me --platforms android .` (klasör adı geçersiz paket adı; yalnızca Android hedefi). Organizasyon varsayılan `com.example` bırakıldı; yayın öncesi değiştirilecek.
- **Adım 0.1:** Boş klasörler `.gitkeep` ile takip ediliyor; tek boş ekran `MapScreen`.
- **Adım 0.3:** Paketler: `maplibre_gl` (harita) + `geolocator` (izin ve konum; `permission_handler` eklenmedi). Sadece ön plan izni (FINE/COARSE), arka plan yok.
- **Adım 0.3:** Harita stili API anahtarı gerektirmeyen OpenFreeMap vektör kaynağı + yerel `assets/map/pastel_style.json` (etiketsiz, bu yüzden glyph gerekmez). Stil JSON'undaki renkler palet hex'leriyle elle eşlendi (JSON `core/theme`'den okuyamaz). Yayın öncesi OpenFreeMap kullanım koşulları/ataf ve kendi tile barındırma değerlendirilecek.
- **Adım 0.3:** Başlangıç kamerası konum alınamazsa İstanbul (41.0082, 28.9784).

