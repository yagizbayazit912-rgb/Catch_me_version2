-- Adım 2.1: para hareketleri (plan bölüm 8).
-- Kural: coins/gems yalnızca apply_transaction ile değişir; her değişim aynı
-- işlemde bir transactions satırı yazar. Negatif bakiye yok (hareket reddedilir).
-- Tablo istemciye sadece kendi satırlarını okumaya açık, yazma yok.

create table public.transactions (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  type           text not null check (length(type) between 1 and 40),
  amount         bigint not null check (amount <> 0),   -- + kazanç, - harcama
  currency       text not null check (currency in ('coins', 'gems')),
  balance_after  bigint not null check (balance_after >= 0),
  ref_id         text,                                  -- ilgili h3 / yapı / sipariş
  created_at     timestamptz not null default now()
);
create index transactions_user_time_idx
  on public.transactions (user_id, created_at desc);

alter table public.transactions enable row level security;

create policy "transactions_select_own"
  on public.transactions for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.transactions from anon, authenticated;
grant select on public.transactions to authenticated;
grant select, insert on public.transactions to service_role;

-- Tek giriş noktası: bakiyeyi kilitleyip günceller ve kaydı yazar.
-- Yetersiz bakiyede 'insufficient_funds' hatası verir (borç oluşmaz).
create or replace function public.apply_transaction(
  p_user     uuid,
  p_type     text,
  p_amount   bigint,
  p_currency text,
  p_ref      text default null
) returns bigint
language plpgsql security definer set search_path = public
as $$
declare
  v_balance bigint;
begin
  if p_currency not in ('coins', 'gems') then
    raise exception 'invalid_currency';
  end if;
  if p_amount = 0 then
    raise exception 'zero_amount';
  end if;

  if p_currency = 'coins' then
    select coins into v_balance from users where id = p_user for update;
  else
    select gems into v_balance from users where id = p_user for update;
  end if;
  if not found then
    raise exception 'user_not_found';
  end if;

  v_balance := v_balance + p_amount;
  if v_balance < 0 then
    raise exception 'insufficient_funds';
  end if;

  if p_currency = 'coins' then
    update users set coins = v_balance where id = p_user;
  else
    update users set gems = v_balance where id = p_user;
  end if;

  insert into transactions (user_id, type, amount, currency, balance_after, ref_id)
    values (p_user, p_type, p_amount, p_currency, v_balance, p_ref);

  return v_balance;
end;
$$;

revoke all on function public.apply_transaction(uuid, text, bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.apply_transaction(uuid, text, bigint, text, text)
  to service_role;
