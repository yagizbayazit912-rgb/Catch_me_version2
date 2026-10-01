-- Adım 0.6: oyuncu profili (users) + RLS.
-- Kural: bakiye/xp/seviye yalnızca sunucu (security definer fonksiyonlar /
-- edge function) tarafından değişir. İstemci sadece kendi satırını okur ve
-- yalnızca kullanıcı adını güncelleyebilir.

create table public.users (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique
              check (username ~ '^[A-Za-z0-9_]{3,20}$'),
  level       integer not null default 1 check (level >= 1),
  xp          bigint  not null default 0 check (xp >= 0),
  coins       bigint  not null default 0 check (coins >= 0),
  gems        bigint  not null default 0 check (gems >= 0),
  created_at  timestamptz not null default now()
);

alter table public.users enable row level security;

-- Okuma: sadece kendi satırı. (Liderlik tablosu vb. için ileride ayrı,
-- kısıtlı bir görünüm/fonksiyon açılacak; tabloyu herkese açma.)
create policy "users_select_own"
  on public.users for select
  to authenticated
  using ((select auth.uid()) = id);

-- Güncelleme: sadece kendi satırı...
create policy "users_update_own"
  on public.users for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ...ve sadece username kolonu (coins/xp/level/gems istemciden değişmez).
-- (Supabase yeni tablolarda anon/authenticated'a varsayılan olarak tüm
-- yetkileri verir; önce hepsini geri al.)
revoke all on public.users from anon, authenticated;
grant select on public.users to authenticated;
grant update (username) on public.users to authenticated;
-- INSERT/DELETE politikası yok: satır kayıt tetikleyicisiyle açılır,
-- auth kullanıcısı silinince cascade ile silinir.

-- Kayıt olunca profil satırı otomatik açılır.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  wanted text := new.raw_user_meta_data ->> 'username';
begin
  if wanted is null
     or wanted !~ '^[A-Za-z0-9_]{3,20}$'
     or exists (select 1 from public.users u where u.username = wanted) then
    wanted := 'oyuncu_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.users (id, username) values (new.id, wanted);
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
