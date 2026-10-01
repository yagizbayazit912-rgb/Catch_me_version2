# Catch Me — Agent Talimatları (KISA, her oturumda bunu oku)

Proje: Konum tabanlı, altıgen (H3 Res 9) bölge sahiplenme oyunu. Flutter + Supabase + MapLibre. Hedef: Android önce, 13+ kitle, tatlı/ferah pastel tasarım, hafif 3D his, tatmin edici animasyonlar.

## Okuma sırası (token tasarrufu için)
1. Bu dosya.
2. `docs/LESSONS.md` → sadece **"Altın Kurallar"** bölümü.
3. `docs/PROJE_PLANI.md` → **yalnızca** bugünkü adımla ilgili bölüm (bölüm 19'daki adım numarası hangi bölüme işaret ediyorsa). Tüm dosyayı baştan sona okuma.

## Çalışma kuralları
- **Bir oturum = bir adım.** Kullanıcı "Adım X.Y" der; sadece onu yap, sonra DUR.
- Kodlamadan önce en fazla 5 satırlık plan yaz, sonra uygula. Uzun açıklama yazma.
- Dosyaları baştan yazma; **hedefli düzenleme** yap. Gerekmedikçe büyük dosya/çıktıyı sohbete yapıştırma.
- Gereksiz yere tüm projeyi derleme/test etme; değişen yeri doğrula (`flutter analyze` değişen dosyalar, ilgili test).
- Adım bitince **en fazla 5 satırlık özet** ver: ne yapıldı, nasıl test edilir, sıradaki adım.
- Adım bitince `docs/LESSONS.md`'ye giriş ekle (hata ✅/❌ fark etmez, kısa).
- Adım bittiğinde git commit at (`adim-X.Y: kısa açıklama`).
- Emin olmadığın büyük karar çıkarsa kullanıcıya **tek soru** sor; küçük kararlarda varsayım yap, `docs/DECISIONS.md`'ye not et.

## Değişmez kurallar
- Para, sahiplik, kira, claim kararları **sunucuda**. İstemci sadece ister.
- Sayılar (fiyat, süre, gelir) config'ten okunur, koda gömülmez.
- Renk/yazı tipi sadece `core/theme` üzerinden.
- Diğer oyunculara **kesin koordinat asla** dönme.
- API anahtarı/gizli bilgi repoya yazılmaz. Supabase'de tüm tablolarda RLS açık.
- Animasyonlar UI'yı bloklamaz, atlanabilir, "hareketi azalt" ayarına uyar, düşük donanımda yedek moda düşer.


## Bekleyen işler
Adım 1.2 başladığında ve bitince kullanıcıya hatırlat: Adım 1.6 (Yürüyüş modu) planlandı ve henüz yapılmadı. Yapılınca bu satırı sil.
Adım 0.7 (Google girişi) planlandı ve henüz yapılmadı. Kapalı beta öncesi yapılmalı. Adım 1.2 bitince kullanıcıya hatırlat. Yapılınca bu satırı sil.
