-- Adım 1.2: presence birikimi ve bölge sahiplenme (sunucu kararı).
-- Tüm tablolar sadece service_role'a açık; istemci okuyup yazamaz.
-- Sahiplik okuma (harita) Adım 1.3'te güvenli bir RPC/view ile gelecek.

-- Oyun sayıları burada (koda gömülmez). Değer = jsonb sayı.
create table public.game_config (
  key   text primary key,
  value jsonb not null
);
insert into public.game_config (key, value) values
  ('claim_seconds', '600'),            -- toplam 10 dk (plan 5.1)
  ('claim_window_seconds', '86400'),   -- birikim penceresi: 24 saat
  ('presence_max_credit_s', '60'),     -- tek ping'ten en fazla bu kadar sn sayılır
  ('max_owned_hexes', '5');            -- başlangıç sahiplik limiti (plan 5.2)

create table public.hexes (
  h3_index         text primary key,
  owner_id         uuid references auth.users (id) on delete set null,
  claimed_at       timestamptz,
  last_visited_at  timestamptz,
  is_blocked       boolean not null default false
);
create index hexes_owner_idx on public.hexes (owner_id);

create table public.hex_progress (
  user_id              uuid not null references auth.users (id) on delete cascade,
  h3_index             text not null,
  accumulated_seconds  integer not null default 0 check (accumulated_seconds >= 0),
  window_start         timestamptz not null default now(),
  primary key (user_id, h3_index)
);

alter table public.game_config  enable row level security;
alter table public.hexes        enable row level security;
alter table public.hex_progress enable row level security;
revoke all on public.game_config, public.hexes, public.hex_progress from anon, authenticated;
grant select, insert, update, delete
  on public.game_config, public.hexes, public.hex_progress to service_role;

-- Atomik birikim + sahiplenme. Sadece sunucu çağırır.
create or replace function public.accrue_presence(
  p_user uuid, p_h3 text, p_seconds integer
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_claim   integer := (select (value)::integer from game_config where key = 'claim_seconds');
  v_window  integer := (select (value)::integer from game_config where key = 'claim_window_seconds');
  v_cap     integer := (select (value)::integer from game_config where key = 'presence_max_credit_s');
  v_max     integer := (select (value)::integer from game_config where key = 'max_owned_hexes');
  v_credit  integer := greatest(0, least(p_seconds, v_cap));
  v_acc     integer;
  v_owner   uuid;
  v_claimed boolean := false;
begin
  insert into hexes (h3_index, last_visited_at) values (p_h3, now())
    on conflict (h3_index) do update set last_visited_at = now()
    returning owner_id into v_owner;

  if v_owner = p_user then
    return jsonb_build_object('status', 'owned', 'accumulated', 0, 'required', v_claim);
  end if;

  insert into hex_progress (user_id, h3_index, accumulated_seconds, window_start)
    values (p_user, p_h3, v_credit, now())
    on conflict (user_id, h3_index) do update set
      accumulated_seconds = case
        when hex_progress.window_start < now() - make_interval(secs => v_window)
          then v_credit else hex_progress.accumulated_seconds + v_credit end,
      window_start = case
        when hex_progress.window_start < now() - make_interval(secs => v_window)
          then now() else hex_progress.window_start end
    returning accumulated_seconds into v_acc;

  if v_owner is not null then  -- sahipli bölge: meydan okuma Adım 1.x'te
    return jsonb_build_object('status', 'owned_by_other', 'accumulated', v_acc, 'required', v_claim);
  end if;

  if v_acc >= v_claim
     and (select count(*) from hexes where owner_id = p_user) < v_max then
    update hexes set owner_id = p_user, claimed_at = now()
      where h3_index = p_h3 and owner_id is null and not is_blocked;
    v_claimed := found;  -- yarışta başkası aldıysa false
    if v_claimed then
      delete from hex_progress where user_id = p_user and h3_index = p_h3;
    end if;
  end if;

  return jsonb_build_object(
    'status', case when v_claimed then 'claimed' else 'accruing' end,
    'accumulated', v_acc, 'required', v_claim);
end $$;

revoke all on function public.accrue_presence(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.accrue_presence(uuid, text, integer) to service_role;
