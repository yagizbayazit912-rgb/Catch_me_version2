-- Adım 1.5: temel hile kontrolleri (plan 5.4).
-- location-ping eşikleri koddan game_config'e taşındı. Şüpheli ihlaller
-- (sahte konum, ışınlanma, imkânsız doğruluk) kaydedilir; pencere içinde
-- çok tekrar ederse kullanıcının ping'leri geçici olarak reddedilir.
-- Kayıtta ham koordinat YOK (sadece h3). Tablolar sadece service_role'a açık.

insert into public.game_config (key, value) values
  ('ping_max_accuracy_m', '50'),          -- üstü kötü doğruluk, ret (ihlal değil)
  ('ping_min_accuracy_m', '1'),           -- altı gerçek GPS'te görülmez (sahte konum izi), ret + ihlal
  ('ping_max_speed_mps', '30'),           -- üstü ışınlanma, ret
  ('ping_max_age_s', '120'),              -- istemci zamanı bundan eskiyse ret
  ('ping_teleport_max_gap_s', '1800'),    -- son geçerli ping'ten bu kadar sonra hız kontrolü yapılmaz (uçak/tren sonrası kilitlenme olmasın)
  ('presence_max_speed_kmh', '25'),       -- üstünde varlık birikmez
  ('anticheat_strike_speed_mps', '90'),   -- ışınlanma bu hızın üstündeyse ihlal sayılır (altı: hızlı tren vb., sadece ret)
  ('anticheat_strike_window_s', '3600'),  -- ihlaller bu pencerede sayılır
  ('anticheat_strikes_to_suspend', '3'),  -- pencerede bu kadar ihlal = askı
  ('anticheat_suspend_s', '900')          -- askı süresi (15 dk)
on conflict (key) do nothing;

create table public.anticheat_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  reason      text not null,
  h3_index    text,
  speed_mps   real,
  accuracy_m  real,
  created_at  timestamptz not null default now()
);
create index anticheat_events_user_time_idx
  on public.anticheat_events (user_id, created_at desc);

create table public.user_risk (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  total_strikes    integer not null default 0,
  suspensions      integer not null default 0,
  suspended_until  timestamptz
);

alter table public.anticheat_events enable row level security;
alter table public.user_risk        enable row level security;
revoke all on public.anticheat_events, public.user_risk from anon, authenticated;
grant select, insert, update, delete
  on public.anticheat_events, public.user_risk to service_role;

-- Ping başında tek çağrı: eşikler + varsa aktif askı bitişi.
create or replace function public.ping_guard(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
    'cfg', (select jsonb_object_agg(key, value) from game_config
            where key like 'ping\_%' or key like 'anticheat\_%'
               or key = 'presence_max_speed_kmh'),
    'suspended_until', (select suspended_until from user_risk
                        where user_id = p_user and suspended_until > now())
  );
$$;

-- İhlali kaydet; pencere içindeki ihlal sayısı eşiğe ulaşırsa askıya al.
create or replace function public.record_violation(
  p_user uuid, p_reason text, p_h3 text, p_speed real, p_accuracy real
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_window  integer := (select (value)::integer from game_config where key = 'anticheat_strike_window_s');
  v_limit   integer := (select (value)::integer from game_config where key = 'anticheat_strikes_to_suspend');
  v_suspend integer := (select (value)::integer from game_config where key = 'anticheat_suspend_s');
  v_count   integer;
  v_until   timestamptz;
begin
  insert into anticheat_events (user_id, reason, h3_index, speed_mps, accuracy_m)
    values (p_user, p_reason, p_h3, p_speed, p_accuracy);

  insert into user_risk (user_id, total_strikes) values (p_user, 1)
    on conflict (user_id) do update set total_strikes = user_risk.total_strikes + 1;

  -- Önceki askıdan önceki ihlaller tekrar sayılmasın.
  select count(*) into v_count from anticheat_events e
    where e.user_id = p_user
      and e.created_at > now() - make_interval(secs => v_window)
      and e.created_at > coalesce(
        (select r.suspended_until - make_interval(secs => v_suspend)
           from user_risk r where r.user_id = p_user), '-infinity');

  if v_count >= v_limit then
    v_until := now() + make_interval(secs => v_suspend);
    update user_risk set suspended_until = v_until, suspensions = suspensions + 1
      where user_id = p_user;
  end if;

  return jsonb_build_object('strikes', v_count, 'suspended_until', v_until);
end;
$$;

revoke all on function public.ping_guard(uuid) from public, anon, authenticated;
revoke all on function public.record_violation(uuid, text, text, real, real)
  from public, anon, authenticated;
grant execute on function public.ping_guard(uuid) to service_role;
grant execute on function public.record_violation(uuid, text, text, real, real)
  to service_role;
