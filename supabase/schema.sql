-- Geo Duel: database setup for Supabase.
-- Run this whole file once in Supabase: SQL Editor -> New query -> paste -> Run.
-- Then run seed_questions.sql (generated from data/questions.json).
--
-- Security model:
--   * Every phone signs in anonymously (no email). auth.uid() identifies it.
--   * Players can read only id + nickname of other players (to find friends by ID).
--   * Players can read only their own duels.
--   * All writes go through the functions below, which check the rules.
--   * Scores are calculated here from the answer key, so they can't be faked by the app.

-- ---------------------------------------------------------------- tables

create table if not exists public.players (
  id          text primary key,                       -- the 6-character player ID, e.g. K7M2QX
  user_id     uuid not null unique references auth.users(id) on delete cascade,
  nickname    text not null check (char_length(nickname) between 1 and 16),
  created_at  timestamptz not null default now()
);

-- Answer key: points for each answer of each question (0 = wrong answer).
create table if not exists public.question_answers (
  question_id  int not null,
  answer_index int not null,
  points       int not null,
  primary key (question_id, answer_index)
);

create table if not exists public.matches (
  id            uuid primary key default gen_random_uuid(),
  p1            text not null references public.players(id) on delete cascade,  -- who started it
  p2            text not null references public.players(id) on delete cascade,
  question_ids  int[] not null,
  p1_picks      int[],
  p2_picks      int[],
  p1_score      int,
  p2_score      int,
  created_at    timestamptz not null default now(),
  finished_at   timestamptz
);
create index if not exists matches_p1_idx on public.matches (p1);
create index if not exists matches_p2_idx on public.matches (p2);

-- ---------------------------------------------------------------- row level security

alter table public.players enable row level security;
alter table public.question_answers enable row level security;
alter table public.matches enable row level security;

-- Others may see only your ID and nickname.
revoke all on public.players from anon, authenticated;
grant select (id, nickname) on public.players to authenticated;
drop policy if exists "players are visible" on public.players;
create policy "players are visible" on public.players for select to authenticated using (true);

-- The answer key is never readable directly.
revoke all on public.question_answers from anon, authenticated;

-- Duels: no direct access at all; the app uses my_matches() below.
revoke all on public.matches from anon, authenticated;

-- ---------------------------------------------------------------- helper functions

create or replace function public.my_player_id()
returns text language sql stable security definer set search_path = public as $$
  select id from public.players where user_id = auth.uid()
$$;

-- A duel as seen by player `me`. The opponent's answers stay hidden until `me` has played.
create or replace function public._match_view(m public.matches, me text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id',            m.id,
    'opponent_id',   case when m.p1 = me then m.p2 else m.p1 end,
    'opponent_name', (select nickname from public.players
                      where id = case when m.p1 = me then m.p2 else m.p1 end),
    'question_ids',  m.question_ids,
    'my_picks',      case when m.p1 = me then m.p1_picks else m.p2_picks end,
    'my_score',      case when m.p1 = me then m.p1_score else m.p2_score end,
    'their_done',    (case when m.p1 = me then m.p2_picks else m.p1_picks end) is not null,
    'their_picks',   case when (case when m.p1 = me then m.p1_picks else m.p2_picks end) is null then null
                          when m.p1 = me then m.p2_picks else m.p1_picks end,
    'their_score',   case when (case when m.p1 = me then m.p1_picks else m.p2_picks end) is null then null
                          when m.p1 = me then m.p2_score else m.p1_score end,
    'finished',      m.finished_at is not null,
    'created_at',    m.created_at
  )
$$;
revoke execute on function public._match_view(public.matches, text) from public, anon, authenticated;

-- ---------------------------------------------------------------- functions the app calls

-- Creates your player (with a new unique ID) or updates your nickname. Returns your ID.
create or replace function public.register_player(nick text)
returns text language plpgsql security definer set search_path = public as $$
declare
  existing text;
  new_id   text;
  clean    text := left(coalesce(nullif(trim(nick), ''), 'Player'), 16);
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;

  select id into existing from public.players where user_id = auth.uid();
  if existing is not null then
    update public.players set nickname = clean where id = existing;
    return existing;
  end if;

  loop
    -- 6 characters without look-alikes (no 0/O, 1/I)
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
      into new_id from generate_series(1, 6);
    begin
      insert into public.players (id, user_id, nickname) values (new_id, auth.uid(), clean);
      return new_id;
    exception when unique_violation then
      -- that ID is taken (or this account was just registered): try again / return it
      select id into existing from public.players where user_id = auth.uid();
      if existing is not null then
        return existing;
      end if;
    end;
  end loop;
end;
$$;

-- Starts a duel against another player. Picks 10 questions that neither player has
-- had before (falls back to the least-seen ones once they've played them all).
create or replace function public.create_match(opponent text)
returns json language plpgsql security definer set search_path = public as $$
declare
  me   text := public.my_player_id();
  qids int[];
  m    public.matches;
begin
  if me is null then
    raise exception 'not registered';
  end if;
  opponent := upper(trim(opponent));
  if opponent = me then
    raise exception 'own id';
  end if;
  if not exists (select 1 from public.players where id = opponent) then
    raise exception 'player not found';
  end if;

  with seen as (
    select unnest(question_ids) as q
    from public.matches
    where p1 in (me, opponent) or p2 in (me, opponent)
  ),
  counts as (
    select a.question_id as q, count(s.q) as times
    from (select distinct question_id from public.question_answers) a
    left join seen s on s.q = a.question_id
    group by a.question_id
  )
  select array_agg(q) into qids
  from (select q from counts order by times, random() limit 10) pick;

  if qids is null or array_length(qids, 1) < 10 then
    raise exception 'no questions loaded';
  end if;

  insert into public.matches (p1, p2, question_ids) values (me, opponent, qids) returning * into m;
  return public._match_view(m, me);
end;
$$;

-- Saves your answers for a duel and scores them. picks[i] = index of the answer you chose
-- for question_ids[i] (-1 = no answer in time).
create or replace function public.submit_picks(match_id uuid, picks int[])
returns json language plpgsql security definer set search_path = public as $$
declare
  me    text := public.my_player_id();
  m     public.matches;
  score int;
begin
  select * into m from public.matches where id = match_id for update;
  if not found or me is null or me not in (m.p1, m.p2) then
    raise exception 'match not found';
  end if;
  if coalesce(array_length(picks, 1), 0) <> array_length(m.question_ids, 1) then
    raise exception 'wrong number of answers';
  end if;

  select coalesce(sum(a.points), 0) into score
  from unnest(m.question_ids, picks) as t(q, p)
  join public.question_answers a on a.question_id = t.q and a.answer_index = t.p;

  if m.p1 = me and m.p1_picks is null then
    update public.matches set p1_picks = picks, p1_score = score where id = match_id;
  elsif m.p2 = me and m.p2_picks is null then
    update public.matches set p2_picks = picks, p2_score = score where id = match_id;
  else
    raise exception 'already played';
  end if;

  update public.matches set finished_at = now()
  where id = match_id and p1_picks is not null and p2_picks is not null;

  select * into m from public.matches where id = match_id;
  return public._match_view(m, me);
end;
$$;

-- Your 50 most recent duels, newest first.
create or replace function public.my_matches()
returns json language plpgsql stable security definer set search_path = public as $$
declare
  me text := public.my_player_id();
begin
  if me is null then
    return '[]'::json;
  end if;
  return coalesce((
    select json_agg(public._match_view(m, me) order by m.created_at desc)
    from (select * from public.matches
          where p1 = me or p2 = me
          order by created_at desc limit 50) m
  ), '[]'::json);
end;
$$;

revoke execute on function public.register_player(text) from public, anon;
revoke execute on function public.create_match(text) from public, anon;
revoke execute on function public.submit_picks(uuid, int[]) from public, anon;
revoke execute on function public.my_matches() from public, anon;
revoke execute on function public.my_player_id() from public, anon;
grant execute on function public.register_player(text) to authenticated;
grant execute on function public.create_match(text) to authenticated;
grant execute on function public.submit_picks(uuid, int[]) to authenticated;
grant execute on function public.my_matches() to authenticated;
grant execute on function public.my_player_id() to authenticated;
