-- GELİŞTİRME ARACI: kendi bölgelerini tamamen sıfırlar (yeniden sahiplenme
-- testi için). Sahiplik, yapı, inşa zamanı, gelir sayacı ve birikmiş
-- sahiplenme süresi silinir; bölgeler sahipsiz olur. Harcanan altın geri
-- gelmez (test altını için grant_test_coins.sql).
-- E-postayı kendi giriş e-postanla değiştir, SQL Editor'de çalıştır.

with me as (
  select id from auth.users where email = 'yagizbayazit912@gmail.com'
), progress as (
  delete from public.hex_progress where user_id = (select id from me)
)
update public.hexes
   set owner_id = null, claimed_at = null,
       level = 0, built_at = null, income_at = null
 where owner_id = (select id from me)
returning h3_index;
