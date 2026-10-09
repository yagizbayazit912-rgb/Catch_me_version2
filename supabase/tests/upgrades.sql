-- Adım 2.4 testi — Supabase Dashboard > SQL Editor'e yapıştır, "Run".
-- Geçici kullanıcı + hücre açar, 0→4 inşa/yükseltmeyi dener, sonra siler.
-- Başarılıysa sonuç: "TÜM YÜKSELTME TESTLERİ GEÇTİ".

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000e3', 'up-a@test.local', '{"username":"up_test_a"}');
insert into public.hexes (h3_index, owner_id, claimed_at) values
  ('test_hex_u1', '00000000-0000-4000-8000-0000000000e3', now());

-- 100 + 600 + 3000 + 15000 = 18700
select public.apply_transaction(
  '00000000-0000-4000-8000-0000000000e3', 'test_grant', 18700, 'coins');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e3","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  -- 1) Dört seviye sırayla: çadır, ev, otel, gökdelen
  for i in 1..4 loop
    r := public.build_structure('test_hex_u1');
    if (r->>'level')::int <> i then
      raise exception 'FAIL 1: seviye % beklendi, %', i, r;
    end if;
  end loop;
  if (r->>'coins')::int <> 0 then
    raise exception 'FAIL 1b: bakiye 0 olmalı, %', r;
  end if;

  -- 2) Üst sınır
  begin
    perform public.build_structure('test_hex_u1');
    raise exception 'FAIL 2: 4 üstüne çıktı';
  exception when raise_exception then
    if sqlerrm <> 'max_level' then raise; end if;
  end;

  -- 3) Haritada seviye 4
  if (select level from public.owned_hexes_in(array['test_hex_u1'])) <> 4 then
    raise exception 'FAIL 3: owned_hexes_in seviye 4 dönmüyor';
  end if;
end $$;

reset role;
-- 4) Yükseltmede eski kasa toplanır: ev (25/sa) 2 saat önce kurulmuş gibi
--    → 50 altın verilir, sayaç sıfırlanır.
update public.hexes set level = 2, income_at = now() - interval '2 hours'
  where h3_index = 'test_hex_u1';
select public.apply_transaction(
  '00000000-0000-4000-8000-0000000000e3', 'test_grant', 2950, 'coins');
set local role authenticated;
do $$
declare r jsonb;
begin
  r := public.build_structure('test_hex_u1');   -- otel 3000 = 2950 + 50
  if (r->>'level')::int <> 3 or (r->>'collected')::int <> 50
     or (r->>'coins')::int <> 0 then
    raise exception 'FAIL 4: %', r;
  end if;
end $$;

reset role;
do $$
declare a constant uuid := '00000000-0000-4000-8000-0000000000e3';
begin
  -- 5) Kayıtlar: 5 build, 1 income (ref = hücre), sayaç şimdiye çekildi
  if (select count(*) from transactions where user_id = a and type = 'build') <> 5
     or (select count(*) from transactions where user_id = a and type = 'income'
           and amount = 50 and ref_id = 'test_hex_u1') <> 1 then
    raise exception 'FAIL 5: transaction kayıtları yanlış';
  end if;
  if (select income_at from hexes where h3_index = 'test_hex_u1')
       < now() - interval '1 minute' then
    raise exception 'FAIL 5b: gelir sayacı sıfırlanmadı';
  end if;
end $$;

-- ---- Temizlik ----
delete from public.hexes where h3_index = 'test_hex_u1';
delete from auth.users where id = '00000000-0000-4000-8000-0000000000e3';

select 'TÜM YÜKSELTME TESTLERİ GEÇTİ' as sonuc;
