-- Adım 1.4: haritada sahipli altıgenleri okuma.
-- hexes tablosu istemciye kapalı kalır; istemci sadece görünür alandaki
-- h3 indekslerini sorar. Dönen: h3, benim mi, renk tohumu. owner_id,
-- koordinat, zaman bilgisi dönmez.

insert into public.game_config (key, value) values
  ('max_visible_hexes', '600')   -- tek istekte sorulabilecek en fazla hücre
on conflict (key) do nothing;

create or replace function public.owned_hexes_in(p_cells text[])
returns table (h3_index text, is_mine boolean, color_seed integer)
language sql stable security definer set search_path = public
as $$
  select h.h3_index,
         h.owner_id = auth.uid(),
         mod(hashtext(h.owner_id::text)::bigint + 2147483648, 1000)::integer
  from hexes h
  where auth.uid() is not null
    and h.owner_id is not null
    and h.h3_index = any (
      p_cells[1:(select (value)::integer from game_config where key = 'max_visible_hexes')]
    );
$$;

revoke all on function public.owned_hexes_in(text[]) from public, anon;
grant execute on function public.owned_hexes_in(text[]) to authenticated;
