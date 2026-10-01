-- Adım 0.6 RLS testi — Supabase Dashboard > SQL Editor'e yapıştır, "Run".
-- Geçici iki kullanıcı açar, A gibi davranıp kuralları dener, sonra siler.
-- Herhangi bir kontrol başarısız olursa hata verir ve her şey geri alınır.
-- Başarılıysa sonuç: "TÜM RLS TESTLERİ GEÇTİ".

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'rls-a@test.local', '{"username":"rls_test_a"}'),
  ('00000000-0000-4000-8000-0000000000b2', 'rls-b@test.local', '{"username":"rls_test_b"}');

-- Tetikleyici profilleri açtı mı?
do $$ begin
  if (select count(*) from public.users
      where id in ('00000000-0000-4000-8000-0000000000a1',
                   '00000000-0000-4000-8000-0000000000b2')) <> 2 then
    raise exception 'FAIL: kayıt tetikleyicisi profil açmadı';
  end if;
end $$;

-- ---- Artık giriş yapmış kullanıcı A'yız ----
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

do $$
declare n int;
begin
  -- 1) Kendi satırını görür
  select count(*) into n from public.users
   where id = '00000000-0000-4000-8000-0000000000a1';
  if n <> 1 then raise exception 'FAIL 1: A kendi satırını göremiyor'; end if;

  -- 2) Başkasının satırını görmez
  select count(*) into n from public.users
   where id = '00000000-0000-4000-8000-0000000000b2';
  if n <> 0 then raise exception 'FAIL 2: A, B''nin satırını görüyor'; end if;

  -- 3) Kendi kullanıcı adını değiştirebilir
  update public.users set username = 'rls_test_a2'
   where id = '00000000-0000-4000-8000-0000000000a1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 3: A kullanıcı adını değiştiremedi'; end if;

  -- 4) Başkasının satırını değiştiremez
  update public.users set username = 'hacked'
   where id = '00000000-0000-4000-8000-0000000000b2';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 4: A, B''nin satırını değiştirdi'; end if;

  -- 5) Kendi coin'ini değiştiremez (kolon yetkisi yok)
  begin
    update public.users set coins = 999999
     where id = '00000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL 5: A coin değiştirebildi';
  exception when insufficient_privilege then null;
  end;

  -- 6) Elle satır ekleyemez
  begin
    insert into public.users (id, username)
    values (gen_random_uuid(), 'sahte_hesap');
    raise exception 'FAIL 6: A satır ekleyebildi';
  exception when insufficient_privilege then null;
  end;

  -- 7) Satır silemez
  begin
    delete from public.users where id = '00000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL 7: A satır silebildi';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- Giriş yapmamış (anon) ----
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

do $$ begin
  -- 8) Anon tabloyu okuyamaz
  begin
    perform 1 from public.users limit 1;
    raise exception 'FAIL 8: anon tabloyu okuyabildi';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---- Temizlik ----
reset role;
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000a1',
                                    '00000000-0000-4000-8000-0000000000b2');

select 'TÜM RLS TESTLERİ GEÇTİ' as sonuc;
