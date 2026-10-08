-- Adım 2.2: çadır inşası (plan bölüm 6, 19).
-- Yapı hücrede `level` alanıyla tutulur: 0 = yapı yok, 1 = çadır (2–4 sonra).
-- Yapı tipi seviyeden türer. İnşa kararı ve ödeme sunucuda, tek işlemde:
-- sahiplik + seviye kontrolü + apply_transaction (yetersizse hiçbir şey değişmez).

alter table public.hexes
  add column level    smallint not null default 0 check (level between 0 and 4),
  add column built_at timestamptz;

insert into public.game_config (key, value) values
  ('build_cost_1', '100')   -- çadır (plan bölüm 6, dengelemede değişebilir)
on conflict (key) do nothing;

-- Dönüş tipi değiştiği için önce düşür (create or replace tip değiştiremez).
drop function if exists public.owned_hexes_in(text[]);

create function public.owned_hexes_in(p_cells text[])
returns table (h3_index text, is_mine boolean, color_seed integer, level smallint)
language sql stable security definer set search_path = public
as $$
  select h.h3_index,
         h.owner_id = auth.uid(),
         mod(hashtext(h.owner_id::text)::bigint + 2147483648, 1000)::integer,
         h.level
  from hexes h
  where auth.uid() is not null
    and h.owner_id is not null
    and h.h3_index = any (
      p_cells[1:(select (value)::integer from game_config where key = 'max_visible_hexes')]
    );
$$;

revoke all on function public.owned_hexes_in(text[]) from public, anon;
grant execute on function public.owned_hexes_in(text[]) to authenticated;

-- Oyuncu kendi, yapısız hücresine çadır kurar. Hata kodları:
-- not_authenticated, not_owner, already_built, insufficient_funds.
create or replace function public.build_structure(p_h3 text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_owner   uuid;
  v_level   smallint;
  v_cost    bigint := (select (value)::bigint from game_config where key = 'build_cost_1');
  v_balance bigint;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if v_cost is null then
    raise exception 'config_missing';
  end if;

  select owner_id, level into v_owner, v_level
    from hexes where h3_index = p_h3 for update;
  if not found or v_owner is distinct from v_user then
    raise exception 'not_owner';
  end if;
  if v_level >= 1 then
    raise exception 'already_built';
  end if;

  v_balance := apply_transaction(v_user, 'build', -v_cost, 'coins', p_h3);

  update hexes set level = 1, built_at = now() where h3_index = p_h3;

  return jsonb_build_object('level', 1, 'coins', v_balance, 'cost', v_cost);
end;
$$;

revoke all on function public.build_structure(text) from public, anon;
grant execute on function public.build_structure(text) to authenticated;
