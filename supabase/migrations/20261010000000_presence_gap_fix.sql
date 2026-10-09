-- Düzeltme (2026-10-10): sahiplenme süresinde bedava süre.
-- Aynı altıgende uzun aradan sonra gelen ilk ping (yürüyüş yeniden açıldı,
-- bağlantı koptu) aradaki süreyi `presence_max_credit_s` (60 sn) tavanına
-- kırpıp sayıyordu → oyuncu orada olmadan 1 dk kazanıyordu. Artık tavanı aşan
-- aralık 0 sayılır. Normal yürüyüşte ping aralığı 15 sn, değişmez.
-- Tekrar çalıştırılabilir.

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
  -- Aralık tavanı aşarsa süreklilik bozulmuştur (uygulama kapalıydı, bağlantı
  -- koptu): hiç sayılmaz. Önceden tavana kırpılıp bedava süre veriyordu.
  v_credit  integer := case when p_seconds > v_cap then 0
                            else greatest(0, p_seconds) end;
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
