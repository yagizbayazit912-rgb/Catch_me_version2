-- GELİŞTİRME ARACI (oyunda altın kazanma yolu gelene kadar).
-- Kendi hesabına test altını verir; kayıt `transactions`'a 'dev_grant' olarak düşer.
-- E-postayı kendi giriş e-postanla değiştir, SQL Editor'de çalıştır.

select public.apply_transaction(
  (select id from auth.users where email = 'BURAYA_EPOSTA'),
  'dev_grant', 500, 'coins', null
) as yeni_bakiye;
