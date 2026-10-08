-- Adım 2.2 testi — Supabase Dashboard > SQL Editor'e yapıştır, "Run".
-- Geçici iki kullanıcı + iki hücre açar, inşa kurallarını dener, sonra siler.
-- Başarılıysa sonuç: "TÜM YAPI TESTLERİ GEÇTİ".

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000e1', 'st-a@test.local', '{"username":"st_test_a"}'),
  ('00000000-0000-4000-8000-0000000000f2', 'st-b@test.local', '{"username":"st_test_b"}');

insert into public.hexes (h3_index, owner_id, claimed_at) values
  ('test_hex_a1', '00000000-0000-4000-8000-0000000000e1', now()),
  ('test_hex_a2', '00000000-0000-4000-8000-0000000000e1', now());

-- A'ya 150 altın (çadır 100).
select public.apply_transaction(
  '00000000-0000-4000-8000-0000000000e1', 'test_grant', 150, 'coins');

-- ---- Giriş yapmış kullanıcı B: A'nın hücresine kuramaz ----
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
do $$ begin
  begin
    perform public.build_structure('test_hex_a1');
    raise exception 'FAIL 1: B, A''nın hücresine kurdu';
  exception when raise_exception then
    if sqlerrm <> 'not_owner' then raise; end if;
  end;
end $$;

-- ---- Giriş yapmış kullanıcı A ----
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  -- 2) Kendi hücresine kurar: seviye 1, bakiye 50
  r := public.build_structure('test_hex_a1');
  if (r->>'level')::int <> 1 or (r->>'coins')::int <> 50 then
    raise exception 'FAIL 2: %', r;
  end if;

  -- 3) İkinci kez kuramaz
  begin
    perform public.build_structure('test_hex_a1');
    raise exception 'FAIL 3: iki kez kurdu';
  exception when raise_exception then
    if sqlerrm <> 'already_built' then raise; end if;
  end;

  -- 4) Yetersiz bakiye: reddedilir
  begin
    perform public.build_structure('test_hex_a2');
    raise exception 'FAIL 4: yetersiz bakiyeyle kurdu';
  exception when raise_exception then
    if sqlerrm <> 'insufficient_funds' then raise; end if;
  end;

  -- 5) Sahipsiz/olmayan hücre
  begin
    perform public.build_structure('test_hex_yok');
    raise exception 'FAIL 5: olmayan hücreye kurdu';
  exception when raise_exception then
    if sqlerrm <> 'not_owner' then raise; end if;
  end;

  -- 6) Haritada seviye görünür
  if (select level from public.owned_hexes_in(array['test_hex_a1'])) <> 1 then
    raise exception 'FAIL 6: owned_hexes_in seviye dönmüyor';
  end if;
end $$;

-- ---- Sunucu gözüyle kontrol ----
reset role;
do $$
declare a constant uuid := '00000000-0000-4000-8000-0000000000e1';
begin
  -- 7) Başarısız inşa hiçbir şey değiştirmedi
  if (select level from hexes where h3_index = 'test_hex_a2') <> 0 then
    raise exception 'FAIL 7: başarısız inşa seviyeyi değiştirdi';
  end if;
  -- 8) Para hareketi kayıtlı: tek 'build' satırı, -100, ref = hücre
  if (select count(*) from transactions
       where user_id = a and type = 'build' and amount = -100
         and ref_id = 'test_hex_a1') <> 1
     or (select count(*) from transactions where user_id = a and type = 'build') <> 1 then
    raise exception 'FAIL 8: build kaydı yanlış';
  end if;
  if (select coins from users where id = a) <> 50 then
    raise exception 'FAIL 8b: bakiye yanlış';
  end if;
end $$;

-- ---- Temizlik ----
delete from public.hexes where h3_index in ('test_hex_a1', 'test_hex_a2', 'test_hex_yok');
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000e1',
                                    '00000000-0000-4000-8000-0000000000f2');

select 'TÜM YAPI TESTLERİ GEÇTİ' as sonuc;
