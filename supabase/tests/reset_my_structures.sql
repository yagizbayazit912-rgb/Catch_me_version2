-- GELİŞTİRME ARACI: kendi bölgelerindeki yapıları sıfırlar (seviye 0).
-- Sahiplik kalır; yapı, inşa zamanı ve gelir sayacı silinir. Harcanan altın
-- geri gelmez (test altını için grant_test_coins.sql).
-- E-postayı kendi giriş e-postanla değiştir, SQL Editor'de çalıştır.

update public.hexes
   set level = 0, built_at = null, income_at = null
 where owner_id = (select id from auth.users
                    where email = 'yagizbayazit912@gmail.com')
returning h3_index, level;
