-- Adım 2.3 testi — Supabase Dashboard > SQL Editor'e yapıştır, "Run".
-- Geçici iki kullanıcı + çadırlı hücreler açar, gelir/toplama kurallarını
-- dener, sonra siler. Başarılıysa sonuç: "TÜM GELİR TESTLERİ GEÇTİ".
-- (Çadır 5/sa, tavan 8 sa varsayılır; config farklıysa beklenen sayılar değişir.)

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000c1', 'in-a@test.local', '{"username":"in_test_a"}'),
  ('00000000-0000-4000-8000-0000000000c2', 'in-b@test.local', '{"username":"in_test_b"}');

-- a1: 2 sa önce (10), a2: 90 dk önce (7,5 → 7), a3: 20 sa önce (tavan 40),
-- a4: yapısız (gelir yok).
insert into public.hexes (h3_index, owner_id, claimed_at, level, built_at) values
  ('test_in_a1', '00000000-0000-4000-8000-0000000000c1', now(), 1, now() - interval '2 hours'),
  ('test_in_a2', '00000000-0000-4000-8000-0000000000c1', now(), 1, now() - interval '90 minutes'),
  ('test_in_a3', '00000000-0000-4000-8000-0000000000c1', now(), 1, now() - interval '20 hours'),
  ('test_in_a4', '00000000-0000-4000-8000-0000000000c1', now(), 0, null);

set local role authenticated;

-- ---- B, A'nın kasasını görmez; toplayınca bir şey almaz ----
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  if (select count(*) from public.my_income()) <> 0 then
    raise exception 'FAIL 1: B, A''nın gelirini görüyor';
  end if;
  r := public.collect_income();
  if (r->>'total')::int <> 0 then
    raise exception 'FAIL 1b: B gelir topladı: %', r;
  end if;
end $$;

-- ---- A ----
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  -- 2) Kasa: 3 çadır, 10 + 7 + 40, sadece a3 dolu
  if (select count(*) from public.my_income()) <> 3
     or (select sum(pending) from public.my_income()) <> 57
     or (select cap from public.my_income() where h3_index = 'test_in_a3') <> 40
     or not (select is_full from public.my_income() where h3_index = 'test_in_a3')
     or (select is_full from public.my_income() where h3_index = 'test_in_a1') then
    raise exception 'FAIL 2: my_income yanlış';
  end if;

  -- 3) Topla: 57 altın, bakiye 57, hücre dağılımı 3 satır
  r := public.collect_income();
  if (r->>'total')::int <> 57 or (r->>'coins')::int <> 57
     or jsonb_array_length(r->'items') <> 3 then
    raise exception 'FAIL 3: %', r;
  end if;

  -- 4) Hemen tekrar: 0 (çift toplama yok), bakiye aynı
  r := public.collect_income();
  if (r->>'total')::int <> 0 or (r->>'coins')::int <> 57 then
    raise exception 'FAIL 4: %', r;
  end if;
end $$;

-- ---- Sunucu gözüyle kontrol ----
reset role;
do $$
declare a constant uuid := '00000000-0000-4000-8000-0000000000c1';
begin
  -- 5) Kesir korunur: a2 sayacı 7 sikke = 84 dk ilerledi (6 dk artık kalır)
  if (select income_at from hexes where h3_index = 'test_in_a2')
       <> now() - interval '6 minutes' then
    raise exception 'FAIL 5: kesirli gelir kayboldu';
  end if;
  -- 6) Tavan dolan hücre şimdiye çekildi
  if (select income_at from hexes where h3_index = 'test_in_a3') <> now() then
    raise exception 'FAIL 6: tavan sonrası sayaç yanlış';
  end if;
  -- 7) Para hareketi kayıtlı: tek 'income' satırı, +57
  if (select count(*) from transactions
       where user_id = a and type = 'income' and amount = 57) <> 1
     or (select count(*) from transactions where user_id = a) <> 1 then
    raise exception 'FAIL 7: income kaydı yanlış';
  end if;
end $$;

-- 8) Anonim çağıramaz
set local role anon;
do $$ begin
  begin
    perform public.collect_income();
    raise exception 'FAIL 8: anon topladı';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ---- Temizlik ----
delete from public.hexes where h3_index like 'test_in_a%';
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000c1',
                                    '00000000-0000-4000-8000-0000000000c2');

select 'TÜM GELİR TESTLERİ GEÇTİ' as sonuc;
