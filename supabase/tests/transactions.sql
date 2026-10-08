-- Adım 2.1 testi — Supabase Dashboard > SQL Editor'e yapıştır, "Run".
-- Geçici iki kullanıcı açar, kuralları dener, sonra siler.
-- Başarılıysa sonuç: "TÜM TRANSACTION TESTLERİ GEÇTİ".

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000c1', 'tx-a@test.local', '{"username":"tx_test_a"}'),
  ('00000000-0000-4000-8000-0000000000d2', 'tx-b@test.local', '{"username":"tx_test_b"}');

do $$
declare
  a constant uuid := '00000000-0000-4000-8000-0000000000c1';
  n int; bal bigint;
begin
  -- 1) Kazanç bakiyeyi artırır ve kayıt yazar
  bal := apply_transaction(a, 'test_grant', 100, 'coins', 'x');
  if bal <> 100 then raise exception 'FAIL 1: bakiye %', bal; end if;

  -- 2) Harcama bakiyeyi düşürür
  bal := apply_transaction(a, 'test_spend', -30, 'coins');
  if bal <> 70 then raise exception 'FAIL 2: bakiye %', bal; end if;

  -- 3) Yetersiz bakiye reddedilir, bakiye değişmez, kayıt yazılmaz
  begin
    perform apply_transaction(a, 'test_spend', -71, 'coins');
    raise exception 'FAIL 3: negatif bakiyeye izin verdi';
  exception when raise_exception then
    if sqlerrm <> 'insufficient_funds' then raise; end if;
  end;
  if (select coins from users where id = a) <> 70 then
    raise exception 'FAIL 3b: bakiye değişti';
  end if;

  -- 4) Her hareket tam bir kayıt: 2 satır, son bakiye tutarlı
  select count(*) into n from transactions where user_id = a;
  if n <> 2 then raise exception 'FAIL 4: % kayıt', n; end if;
  if (select sum(amount) from transactions where user_id = a and currency = 'coins')
       <> (select coins from users where id = a) then
    raise exception 'FAIL 4b: kayıt toplamı bakiyeyle uyuşmuyor';
  end if;

  -- 5) Gems ayrı bakiye
  bal := apply_transaction(a, 'test_grant', 5, 'gems');
  if bal <> 5 or (select coins from users where id = a) <> 70 then
    raise exception 'FAIL 5: gems/coins karıştı';
  end if;

  -- 6) Geçersiz para birimi ve sıfır tutar reddedilir
  begin
    perform apply_transaction(a, 't', 1, 'gold');
    raise exception 'FAIL 6: geçersiz para birimi kabul edildi';
  exception when raise_exception then
    if sqlerrm <> 'invalid_currency' then raise; end if;
  end;
  begin
    perform apply_transaction(a, 't', 0, 'coins');
    raise exception 'FAIL 6b: sıfır tutar kabul edildi';
  exception when raise_exception then
    if sqlerrm <> 'zero_amount' then raise; end if;
  end;
end $$;

-- ---- Giriş yapmış kullanıcı A ----
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

do $$
declare n int;
begin
  -- 7) Sadece kendi kayıtlarını görür
  select count(*) into n from public.transactions;
  if n <> 3 then raise exception 'FAIL 7: A % kayıt görüyor', n; end if;

  -- 8) Kayıt ekleyemez, silemez, değiştiremez
  begin
    insert into public.transactions (user_id, type, amount, currency, balance_after)
      values ('00000000-0000-4000-8000-0000000000c1', 'hack', 999, 'coins', 999);
    raise exception 'FAIL 8: A kayıt ekledi';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.transactions;
    raise exception 'FAIL 8b: A kayıt sildi';
  exception when insufficient_privilege then null;
  end;

  -- 9) Fonksiyonu çağıramaz (para üretemez)
  begin
    perform public.apply_transaction(
      '00000000-0000-4000-8000-0000000000c1', 'hack', 999, 'coins');
    raise exception 'FAIL 9: A apply_transaction çağırdı';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- Giriş yapmış kullanıcı B: A'nın kayıtlarını görmez ----
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.transactions) <> 0 then
    raise exception 'FAIL 10: B, A''nın kayıtlarını görüyor';
  end if;
end $$;

-- ---- anon ----
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin
    perform 1 from public.transactions limit 1;
    raise exception 'FAIL 11: anon tabloyu okudu';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- Temizlik ----
reset role;
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000c1',
                                    '00000000-0000-4000-8000-0000000000d2');

select 'TÜM TRANSACTION TESTLERİ GEÇTİ' as sonuc;
