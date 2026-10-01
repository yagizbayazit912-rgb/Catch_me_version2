-- Adım 1.1: location/ping servisinin son konum durumu.
-- Hız/ışınlanma kontrolü için kullanıcının son GEÇERLİ ping'i tutulur.
-- Kural: sadece sunucu (edge function, service_role) yazar/okur; istemci
-- bu tabloya hiç erişemez (başkasının/kendi ham koordinatı dahil).

create table public.ping_state (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  accuracy_m  real not null check (accuracy_m >= 0),
  h3_index    text not null,
  pinged_at   timestamptz not null default now()
);

alter table public.ping_state enable row level security;

-- Politika yok = authenticated/anon için varsayılan ret. Supabase'in
-- varsayılan grant'lerini de geri al (Adım 0.6 dersi).
revoke all on public.ping_state from anon, authenticated;
grant select, insert, update, delete on public.ping_state to service_role;
