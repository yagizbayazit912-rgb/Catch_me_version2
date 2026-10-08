-- Adım 2.3: gelir birikimi ve "topla" (plan bölüm 6 "Gelir işleyişi").
-- Gelir sunucuda zamandan hesaplanır (çevrimdışı da birikir), tavan
-- `income_cap_hours` saatlik gelirdir. Toplama tek işlemde: hücreleri kilitle,
-- hesapla, sayaçları ilerlet, altını apply_transaction ile ver.
-- Saatlik gelir seviyeye göre config'te: income_per_hour_<level>.

-- Tekrar çalıştırılabilir.
alter table public.hexes
  add column if not exists income_at timestamptz;  -- gelirin sayıldığı başlangıç

insert into public.game_config (key, value) values
  ('income_per_hour_1', '5'),   -- çadır (plan bölüm 6)
  ('income_cap_hours',  '8')    -- depolama tavanı (saatlik gelir × 8)
on conflict (key) do nothing;

-- Bekleyen gelir: tam sikke (aşağı yuvarlanır), tavan ve tavan doldu mu.
-- income_at yoksa (henüz hiç toplanmadı) inşa zamanından sayılır.
create or replace function public.income_state(p_level smallint, p_since timestamptz)
returns table (rate numeric, pending bigint, cap bigint, is_full boolean)
language sql stable set search_path = public
as $$
  with c as (
    select (select (value)::numeric from game_config
              where key = 'income_per_hour_' || p_level) as rate,
           (select (value)::numeric from game_config
              where key = 'income_cap_hours') as cap_h,
           greatest(extract(epoch from now() - p_since), 0) as secs
  )
  select rate,
         floor(rate * least(secs, cap_h * 3600) / 3600)::bigint,
         floor(rate * cap_h)::bigint,
         secs >= cap_h * 3600
  from c
  where rate > 0 and cap_h > 0 and p_since is not null;
$$;

revoke all on function public.income_state(smallint, timestamptz)
  from public, anon, authenticated;

-- Oyuncunun yapılı hücrelerinin kasası (haritadaki çip ve kart için).
create or replace function public.my_income()
returns table (h3_index text, pending bigint, cap bigint, rate numeric, is_full boolean)
language sql stable security definer set search_path = public
as $$
  select h.h3_index, s.pending, s.cap, s.rate, s.is_full
  from hexes h
  cross join lateral income_state(h.level, coalesce(h.income_at, h.built_at)) s
  where auth.uid() is not null
    and h.owner_id = auth.uid()
    and h.level >= 1;
$$;

revoke all on function public.my_income() from public, anon;
grant execute on function public.my_income() to authenticated;

-- Tüm yapılardaki geliri toplar. Kesirli kısım kaybolmaz: sayaç sadece
-- verilen sikke kadar ilerler; tavan dolduysa şimdiye çekilir (fazlası yanar).
-- Dönen: toplam, yeni bakiye, hücre başı dağılım (animasyon için).
create or replace function public.collect_income()
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_total   bigint := 0;
  v_items   jsonb := '[]'::jsonb;
  v_balance bigint;
  r         record;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if not exists (select 1 from game_config where key = 'income_cap_hours') then
    raise exception 'config_missing';
  end if;

  for r in
    select h.h3_index, coalesce(h.income_at, h.built_at) as since, s.*
    from hexes h
    cross join lateral income_state(h.level, coalesce(h.income_at, h.built_at)) s
    where h.owner_id = v_user and h.level >= 1
    order by h.h3_index
    for update of h
  loop
    continue when r.pending <= 0;
    update hexes
       set income_at = case
             when r.is_full then now()
             else r.since + make_interval(secs => (r.pending * 3600 / r.rate)::double precision)
           end
     where h3_index = r.h3_index;
    v_total := v_total + r.pending;
    v_items := v_items || jsonb_build_object('h3', r.h3_index, 'coins', r.pending);
  end loop;

  if v_total > 0 then
    v_balance := apply_transaction(v_user, 'income', v_total, 'coins', null);
  else
    select coins into v_balance from users where id = v_user;
  end if;

  return jsonb_build_object('total', v_total, 'coins', v_balance, 'items', v_items);
end;
$$;

revoke all on function public.collect_income() from public, anon;
grant execute on function public.collect_income() to authenticated;
