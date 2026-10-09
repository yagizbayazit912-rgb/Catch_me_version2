-- Adım 2.4: ev / otel / gökdelen (seviye 2–4) ve yükseltme (plan bölüm 6, 19).
-- build_structure artık bir sonraki seviyeyi kurar (0→1 çadır, 1→2 ev, ...).
-- Yükseltmeden önce eski seviyenin bekleyen geliri otomatik toplanır (oran
-- değişince kayıp/haksız kazanç olmasın) ve sayaç sıfırlanır; ödeme bu
-- altınla da yapılabilir. Hepsi tek işlem: yetersizse hiçbir şey değişmez.
-- Oyuncu seviyesi şartı (plan tablosu) oyuncu seviyesi gelince eklenecek.
-- Tekrar çalıştırılabilir.

insert into public.game_config (key, value) values
  ('build_cost_2', '600'),          -- ev (plan bölüm 6, dengelemede değişebilir)
  ('build_cost_3', '3000'),         -- otel
  ('build_cost_4', '15000'),        -- gökdelen
  ('income_per_hour_2', '25'),
  ('income_per_hour_3', '120'),
  ('income_per_hour_4', '500'),
  ('max_structure_level', '4')
on conflict (key) do nothing;

-- Hata kodları: not_authenticated, not_owner, max_level, insufficient_funds,
-- config_missing. Dönen: yeni seviye, bakiye, maliyet, otomatik toplanan.
create or replace function public.build_structure(p_h3 text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_user      uuid := auth.uid();
  v_owner     uuid;
  v_level     smallint;
  v_since     timestamptz;
  v_next      smallint;
  v_max       smallint := (select (value)::smallint from game_config
                             where key = 'max_structure_level');
  v_cost      bigint;
  v_collected bigint := 0;
  v_balance   bigint;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;

  select owner_id, level, coalesce(income_at, built_at)
    into v_owner, v_level, v_since
    from hexes where h3_index = p_h3 for update;
  if not found or v_owner is distinct from v_user then
    raise exception 'not_owner';
  end if;
  if v_max is null then
    raise exception 'config_missing';
  end if;
  if v_level >= v_max then
    raise exception 'max_level';
  end if;

  v_next := v_level + 1;
  v_cost := (select (value)::bigint from game_config
               where key = 'build_cost_' || v_next);
  if v_cost is null then
    raise exception 'config_missing';
  end if;

  -- Eski seviyenin kasası (yeni oranla geriye dönük hesaplanmasın).
  if v_level >= 1 then
    select coalesce(s.pending, 0) into v_collected
      from income_state(v_level, v_since) s;
    v_collected := coalesce(v_collected, 0);
    if v_collected > 0 then
      perform apply_transaction(v_user, 'income', v_collected, 'coins', p_h3);
    end if;
  end if;

  v_balance := apply_transaction(v_user, 'build', -v_cost, 'coins', p_h3);

  update hexes
     set level = v_next,
         built_at = now(),
         income_at = now()
   where h3_index = p_h3;

  return jsonb_build_object(
    'level', v_next, 'coins', v_balance, 'cost', v_cost,
    'collected', v_collected
  );
end;
$$;

revoke all on function public.build_structure(text) from public, anon;
grant execute on function public.build_structure(text) to authenticated;
