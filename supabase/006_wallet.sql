-- Geo Duel update 6: coins, gems, purchases and the equipped theme live on the account.
-- Run once after 005_delete_account.sql (safe to re-run).
--
-- The server is the only one that changes the wallet:
--   * duel coins (score / 10) when you submit a duel on built-in questions
--   * 5 gems for the winner when a built-in duel finishes
--   * practice coins (score / 20, max 100 per day), scored from the answer key
--   * purchases, checked against the price list below
-- Coins saved on a device before this update are imported once (max 2000 coins, 100 gems).

alter table public.players add column if not exists coins int not null default 0;
alter table public.players add column if not exists gems int not null default 0;
alter table public.players add column if not exists owned text[] not null default '{classic,mint,sunset}';
alter table public.players add column if not exists equipped text not null default 'classic';
alter table public.players add column if not exists wallet_imported boolean not null default false;
alter table public.players add column if not exists practice_day date;
alter table public.players add column if not exists practice_coins_today int not null default 0;
alter table public.players drop constraint if exists players_wallet_check;
alter table public.players add constraint players_wallet_check check (coins >= 0 and gems >= 0);

-- Price list. Keep in sync with scripts/theme_catalog.gd and scripts/avatar_parts.gd.
create table if not exists public.shop_items (
  id       text primary key,
  price    int not null check (price >= 0),
  currency text not null check (currency in ('coins', 'gems'))
);
alter table public.shop_items enable row level security;
revoke all on public.shop_items from anon, authenticated;
insert into public.shop_items (id, price, currency) values
  ('classic', 0, 'coins'), ('mint', 0, 'coins'), ('sunset', 0, 'coins'),
  ('ocean', 100, 'coins'), ('candy', 150, 'coins'), ('forest', 200, 'coins'),
  ('paper', 250, 'coins'), ('neon', 400, 'coins'),
  ('galaxy', 50, 'gems'), ('gold', 80, 'gems'),
  ('acc_none', 0, 'coins'), ('acc_glasses', 0, 'coins'), ('acc_flower', 0, 'coins'),
  ('acc_sunglasses', 100, 'coins'), ('acc_cap', 150, 'coins'), ('acc_headphones', 250, 'coins'),
  ('acc_crown', 60, 'gems')
on conflict (id) do update set price = excluded.price, currency = excluded.currency;

create or replace function public._wallet(p public.players)
returns json language sql stable as $$
  select json_build_object('coins', p.coins, 'gems', p.gems, 'owned', p.owned, 'equipped', p.equipped,
                           'imported', p.wallet_imported)
$$;
revoke execute on function public._wallet(public.players) from public, anon, authenticated;

create or replace function public.my_wallet()
returns json language plpgsql stable security definer set search_path = public as $$
declare p public.players;
begin
  select * into p from public.players where id = public.my_player_id();
  if not found then raise exception 'not registered'; end if;
  return public._wallet(p);
end;
$$;

create or replace function public.my_profile()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('id', id, 'nickname', nickname, 'avatar', avatar, 'wallet', public._wallet(p))
  from public.players p where user_id = auth.uid()
$$;

-- Buys a theme or avatar extra. Returns the new wallet.
create or replace function public.buy_item(item text)
returns json language plpgsql security definer set search_path = public as $$
declare
  me text := public.my_player_id();
  it public.shop_items;
  p  public.players;
begin
  if me is null then raise exception 'not registered'; end if;
  select * into it from public.shop_items where id = item;
  if not found then raise exception 'unknown item'; end if;
  select * into p from public.players where id = me for update;
  if item = any(p.owned) then return public._wallet(p); end if;
  if (it.currency = 'coins' and p.coins < it.price) or (it.currency = 'gems' and p.gems < it.price) then
    raise exception 'not enough %', it.currency;
  end if;
  update public.players set
    coins = coins - case when it.currency = 'coins' then it.price else 0 end,
    gems  = gems  - case when it.currency = 'gems'  then it.price else 0 end,
    owned = array_append(owned, item)
  where id = me returning * into p;
  return public._wallet(p);
end;
$$;

-- Wears a theme you own. Returns the new wallet.
create or replace function public.equip_theme(theme text)
returns json language plpgsql security definer set search_path = public as $$
declare p public.players;
begin
  select * into p from public.players where id = public.my_player_id() for update;
  if not found then raise exception 'not registered'; end if;
  if not theme = any(p.owned) then raise exception 'not owned'; end if;
  update public.players set equipped = theme where id = p.id returning * into p;
  return public._wallet(p);
end;
$$;

-- One-time import of coins/gems/themes saved on a device before accounts had wallets.
create or replace function public.import_wallet(c int, g int, own text[])
returns json language plpgsql security definer set search_path = public as $$
declare p public.players;
begin
  select * into p from public.players where id = public.my_player_id() for update;
  if not found then raise exception 'not registered'; end if;
  if p.wallet_imported then return public._wallet(p); end if;
  update public.players set
    coins = coins + least(greatest(coalesce(c, 0), 0), 2000),
    gems  = gems  + least(greatest(coalesce(g, 0), 0), 100),
    owned = (select array_agg(distinct x) from unnest(owned || coalesce(
               (select array_agg(i.id) from public.shop_items i where i.id = any(own)), '{}')) x),
    wallet_imported = true
  where id = p.id returning * into p;
  return public._wallet(p);
end;
$$;

-- Practice coins: score / 20 from the answer key, at most 100 coins per day.
-- Returns {"coins": awarded, "wallet": {...}}.
create or replace function public.practice_reward(question_ids int[], picks int[])
returns json language plpgsql security definer set search_path = public as $$
declare
  p     public.players;
  score int;
  today int;
  award int;
begin
  select * into p from public.players where id = public.my_player_id() for update;
  if not found then raise exception 'not registered'; end if;
  if coalesce(array_length(question_ids, 1), 0) <> coalesce(array_length(picks, 1), 0)
     or coalesce(array_length(question_ids, 1), 0) > 10 then
    raise exception 'bad answers';
  end if;
  select coalesce(sum(a.points), 0) into score
  from unnest(question_ids, picks) as t(q, pk)
  join public.question_answers a on a.question_id = t.q and a.answer_index = t.pk;
  today := case when p.practice_day = current_date then p.practice_coins_today else 0 end;
  award := least(score / 20, greatest(100 - today, 0));
  update public.players set coins = coins + award, practice_day = current_date,
    practice_coins_today = today + award
  where id = p.id returning * into p;
  return json_build_object('coins', award, 'wallet', public._wallet(p));
end;
$$;

-- Duels now pay out on the server: score / 10 coins when you submit (built-in questions),
-- and 5 gems for the winner when the duel finishes.
create or replace function public.submit_picks(match_id uuid, picks int[])
returns json language plpgsql security definer set search_path = public as $$
declare
  me    text := public.my_player_id();
  m     public.matches;
  score int;
begin
  select * into m from public.matches where id = match_id for update;
  if not found or me is null or me not in (m.p1, m.p2) then raise exception 'match not found'; end if;
  if coalesce(array_length(picks, 1), 0) <> array_length(m.question_ids, 1) then
    raise exception 'wrong number of answers';
  end if;

  if m.level_id is null then
    select coalesce(sum(a.points), 0) into score
    from unnest(m.question_ids, picks) as t(q, p)
    join public.question_answers a on a.question_id = t.q and a.answer_index = t.p;
  else
    select coalesce(sum(((l.questions -> (t.q - 1)) -> 'answers' -> t.p ->> 'p')::int), 0) into score
    from unnest(m.question_ids, picks) as t(q, p), public.levels l
    where l.id = m.level_id and t.p >= 0;
  end if;

  if m.p1 = me and m.p1_picks is null then
    update public.matches set p1_picks = picks, p1_score = score where id = match_id;
  elsif m.p2 = me and m.p2_picks is null then
    update public.matches set p2_picks = picks, p2_score = score where id = match_id;
  else
    raise exception 'already played';
  end if;

  if m.level_id is null then
    update public.players set coins = coins + score / 10 where id = me;
  end if;

  update public.matches set finished_at = now()
  where id = match_id and p1_picks is not null and p2_picks is not null and finished_at is null
  returning * into m;
  if m.finished_at is not null and m.level_id is null and m.p1_score <> m.p2_score then
    update public.players set gems = gems + 5
    where id = case when m.p1_score > m.p2_score then m.p1 else m.p2 end;
  end if;

  select * into m from public.matches where id = match_id;
  return public._match_view(m, me);
end;
$$;

revoke execute on function public.my_wallet() from public, anon;
revoke execute on function public.buy_item(text) from public, anon;
revoke execute on function public.equip_theme(text) from public, anon;
revoke execute on function public.import_wallet(int, int, text[]) from public, anon;
revoke execute on function public.practice_reward(int[], int[]) from public, anon;
grant execute on function public.my_wallet() to authenticated;
grant execute on function public.buy_item(text) to authenticated;
grant execute on function public.equip_theme(text) to authenticated;
grant execute on function public.import_wallet(int, int, text[]) to authenticated;
grant execute on function public.practice_reward(int[], int[]) to authenticated;
