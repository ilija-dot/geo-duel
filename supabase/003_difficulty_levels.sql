-- Geo Duel update 3: difficulty (easy / medium / hard) and player-made levels.
-- Run once after 002_avatars_leaderboard.sql (safe to re-run). Then re-run seed_questions.sql.

-- ---------------------------------------------------------------- difficulty

-- Which pool each built-in question is in. Easy and medium duels use 'easy' questions,
-- hard duels use 'hard' ones. Filled in by seed_questions.sql.
create table if not exists public.question_meta (
  question_id int primary key,
  difficulty  text not null check (difficulty in ('easy', 'hard'))
);
alter table public.question_meta enable row level security;
revoke all on public.question_meta from anon, authenticated;

-- ---------------------------------------------------------------- player-made levels

create table if not exists public.levels (
  id          text primary key,                 -- 6-character share code
  creator     text not null references public.players(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 40),
  questions   jsonb not null,                   -- [{"q": "...", "answers": [{"t": "...", "p": 0|10|25|50|100}]}]
  plays       int not null default 0,
  reports     int not null default 0,
  hidden      boolean not null default false,   -- hidden after 3 reports
  created_at  timestamptz not null default now()
);
create index if not exists levels_creator_idx on public.levels (creator);
alter table public.levels enable row level security;
revoke all on public.levels from anon, authenticated;

create table if not exists public.level_reports (
  level_id  text not null references public.levels(id) on delete cascade,
  reporter  text not null references public.players(id) on delete cascade,
  primary key (level_id, reporter)
);
alter table public.level_reports enable row level security;
revoke all on public.level_reports from anon, authenticated;

alter table public.matches add column if not exists difficulty text not null default 'medium';
alter table public.matches drop constraint if exists matches_difficulty_check;
alter table public.matches add constraint matches_difficulty_check check (difficulty in ('easy', 'medium', 'hard'));
alter table public.matches add column if not exists level_id text references public.levels(id) on delete cascade;

-- Very basic word filter for player-written text (Macedonian + English).
-- Real moderation still relies on the Report button.
create or replace function public._has_bad_words(txt text)
returns boolean language sql immutable as $$
  select lower(txt) ~ '(fuck|shit|bitch|cunt|dick|pussy|porn|nigg|fag|nazi|whore|slut|пичк|курац|курот|ебам|ебем|ебан|педер|курв|шупак|мајка ти)'
$$;

-- Checks a level's questions. Returns an error message, or null if it's fine.
create or replace function public._level_problem(title text, questions jsonb)
returns text language plpgsql immutable as $$
declare
  q jsonb;
  a jsonb;
  n_right int;
  n_wrong int;
begin
  if char_length(trim(coalesce(title, ''))) not between 1 and 40 then return 'bad title'; end if;
  if public._has_bad_words(title) then return 'bad words'; end if;
  if jsonb_typeof(questions) <> 'array' or jsonb_array_length(questions) not between 3 and 20 then
    return 'needs 3-20 questions';
  end if;
  for q in select * from jsonb_array_elements(questions) loop
    if jsonb_typeof(q -> 'q') <> 'string' or char_length(trim(q ->> 'q')) not between 1 and 120 then
      return 'bad question text';
    end if;
    if public._has_bad_words(q ->> 'q') then return 'bad words'; end if;
    if jsonb_typeof(q -> 'answers') <> 'array' or jsonb_array_length(q -> 'answers') not between 4 and 8 then
      return 'each question needs 4-8 answers';
    end if;
    n_right := 0;
    n_wrong := 0;
    for a in select * from jsonb_array_elements(q -> 'answers') loop
      if jsonb_typeof(a -> 't') <> 'string' or char_length(trim(a ->> 't')) not between 1 and 40
         or jsonb_typeof(a -> 'p') <> 'number' or (a ->> 'p')::int not in (0, 10, 25, 50, 100) then
        return 'bad answer';
      end if;
      if public._has_bad_words(a ->> 't') then return 'bad words'; end if;
      if (a ->> 'p')::int > 0 then n_right := n_right + 1; else n_wrong := n_wrong + 1; end if;
    end loop;
    if n_right < 1 or n_wrong < 1 then return 'each question needs right and wrong answers'; end if;
  end loop;
  return null;
end;
$$;

-- Saves a new level. Returns its share code.
create or replace function public.create_level(title text, questions jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare
  me      text := public.my_player_id();
  problem text := public._level_problem(title, questions);
  new_id  text;
begin
  if me is null then raise exception 'not registered'; end if;
  if problem is not null then raise exception '%', problem; end if;
  if (select count(*) from public.levels where creator = me) >= 50 then
    raise exception 'too many levels';
  end if;
  loop
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
      into new_id from generate_series(1, 6);
    begin
      insert into public.levels (id, creator, title, questions) values (new_id, me, trim(title), questions);
      return new_id;
    exception when unique_violation then
      -- code taken, try another
    end;
  end loop;
end;
$$;

-- Loads a level to play (counts as a play). Hidden levels are only visible to their creator.
create or replace function public.get_level(code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  me  text := public.my_player_id();
  lvl public.levels;
begin
  select * into lvl from public.levels where id = upper(trim(code));
  if not found or (lvl.hidden and lvl.creator is distinct from me) then
    raise exception 'level not found';
  end if;
  update public.levels set plays = plays + 1 where id = lvl.id;
  return json_build_object('id', lvl.id, 'title', lvl.title, 'questions', lvl.questions,
    'creator_name', (select nickname from public.players where id = lvl.creator),
    'plays', lvl.plays + 1, 'hidden', lvl.hidden);
end;
$$;

create or replace function public.my_levels()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('id', id, 'title', title, 'questions', questions,
           'plays', plays, 'hidden', hidden) order by created_at desc), '[]'::json)
  from public.levels where creator = public.my_player_id()
$$;

create or replace function public.delete_level(code text)
returns void language sql security definer set search_path = public as $$
  delete from public.levels where id = upper(trim(code)) and creator = public.my_player_id()
$$;

-- Report a level as inappropriate. 3 different reports hide it.
create or replace function public.report_level(code text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me text := public.my_player_id();
  n  int;
begin
  if me is null then raise exception 'not registered'; end if;
  insert into public.level_reports (level_id, reporter) values (upper(trim(code)), me) on conflict do nothing;
  select count(*) into n from public.level_reports where level_id = upper(trim(code));
  update public.levels set reports = n, hidden = (n >= 3) where id = upper(trim(code));
end;
$$;

-- ---------------------------------------------------------------- duels with difficulty / levels

create or replace function public._match_view(m public.matches, me text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id',              m.id,
    'opponent_id',     case when m.p1 = me then m.p2 else m.p1 end,
    'opponent_name',   op.nickname,
    'opponent_avatar', op.avatar,
    'difficulty',      m.difficulty,
    'level',           (select json_build_object('id', l.id, 'title', l.title, 'questions', l.questions)
                        from public.levels l where l.id = m.level_id),
    'question_ids',    m.question_ids,
    'my_picks',        case when m.p1 = me then m.p1_picks else m.p2_picks end,
    'my_score',        case when m.p1 = me then m.p1_score else m.p2_score end,
    'their_done',      (case when m.p1 = me then m.p2_picks else m.p1_picks end) is not null,
    'their_picks',     case when (case when m.p1 = me then m.p1_picks else m.p2_picks end) is null then null
                            when m.p1 = me then m.p2_picks else m.p1_picks end,
    'their_score',     case when (case when m.p1 = me then m.p1_picks else m.p2_picks end) is null then null
                            when m.p1 = me then m.p2_score else m.p1_score end,
    'finished',        m.finished_at is not null,
    'created_at',      m.created_at
  )
  from public.players op
  where op.id = case when m.p1 = me then m.p2 else m.p1 end
$$;
revoke execute on function public._match_view(public.matches, text) from public, anon, authenticated;

-- Starts a duel. Built-in questions: 10 from the difficulty's pool that neither player has had.
-- Player level: all of that level's questions.
drop function if exists public.create_match(text);
create or replace function public.create_match(opponent text, difficulty text default 'medium', level text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  me   text := public.my_player_id();
  qids int[];
  lvl  public.levels;
  pool text;
  m    public.matches;
begin
  if me is null then raise exception 'not registered'; end if;
  opponent := upper(trim(opponent));
  if opponent = me then raise exception 'own id'; end if;
  if not exists (select 1 from public.players where id = opponent) then raise exception 'player not found'; end if;
  if difficulty not in ('easy', 'medium', 'hard') then raise exception 'bad difficulty'; end if;

  if level is not null then
    select * into lvl from public.levels where id = upper(trim(level));
    if not found or (lvl.hidden and lvl.creator <> me) then raise exception 'level not found'; end if;
    select array_agg(i) into qids from generate_series(1, jsonb_array_length(lvl.questions)) i;
  else
    pool := case when difficulty = 'hard' then 'hard' else 'easy' end;
    with seen as (
      select unnest(question_ids) as q from public.matches
      where level_id is null and (p1 in (me, opponent) or p2 in (me, opponent))
    ),
    counts as (
      select qm.question_id as q, count(s.q) as times
      from public.question_meta qm left join seen s on s.q = qm.question_id
      where qm.difficulty = pool
      group by qm.question_id
    )
    select array_agg(q) into qids from (select q from counts order by times, random() limit 10) pick;
    if qids is null or array_length(qids, 1) < 10 then raise exception 'no questions loaded'; end if;
  end if;

  insert into public.matches (p1, p2, question_ids, difficulty, level_id)
  values (me, opponent, qids, difficulty, lvl.id) returning * into m;
  return public._match_view(m, me);
end;
$$;
revoke execute on function public.create_match(text, text, text) from public, anon;
grant execute on function public.create_match(text, text, text) to authenticated;

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
  update public.matches set finished_at = now()
  where id = match_id and p1_picks is not null and p2_picks is not null;
  select * into m from public.matches where id = match_id;
  return public._match_view(m, me);
end;
$$;

-- Leaderboard: same as before, but duels on player-made levels don't count.
create or replace function public.leaderboard(period text default 'week')
returns json language plpgsql stable security definer set search_path = public as $$
declare
  me        text := public.my_player_id();
  since     timestamptz := '-infinity';
  before    timestamptz := 'infinity';
  this_week timestamptz := date_trunc('week', now());
begin
  if period = 'week' then
    since := this_week;
  elsif period = 'last_week' then
    since := this_week - interval '7 days';
    before := this_week;
  end if;
  return (
    with results as (
      select p1 as player, p2 as opp, (p1_score > p2_score)::int as win, p1_score as pts, finished_at
      from public.matches where level_id is null and finished_at >= since and finished_at < before
      union all
      select p2, p1, (p2_score > p1_score)::int, p2_score, finished_at
      from public.matches where level_id is null and finished_at >= since and finished_at < before
    ),
    capped as (
      select player, least(sum(win), 3) as wins, count(*) as played, sum(pts) as pts
      from results group by player, opp, date_trunc('week', finished_at)
    ),
    totals as (
      select player, sum(wins)::int as wins, sum(played)::int as played, sum(pts)::int as points
      from capped group by player
    ),
    ranked as (
      select t.*, rank() over (order by t.wins desc, t.points desc) as rnk from totals t
    )
    select json_build_object(
      'rows', coalesce((
        select json_agg(json_build_object(
                 'rank', r.rnk, 'id', r.player, 'nickname', p.nickname, 'avatar', p.avatar,
                 'wins', r.wins, 'played', r.played, 'points', r.points)
               order by r.rnk, p.nickname)
        from (select * from ranked order by rnk limit 50) r
        join public.players p on p.id = r.player), '[]'::json),
      'me', (select json_build_object('rank', r.rnk, 'wins', r.wins, 'played', r.played, 'points', r.points)
             from ranked r where r.player = me)
    )
  );
end;
$$;

revoke execute on function public.create_level(text, jsonb) from public, anon;
revoke execute on function public.get_level(text) from public, anon;
revoke execute on function public.my_levels() from public, anon;
revoke execute on function public.delete_level(text) from public, anon;
revoke execute on function public.report_level(text) from public, anon;
grant execute on function public.create_level(text, jsonb) to authenticated;
grant execute on function public.get_level(text) to authenticated;
grant execute on function public.my_levels() to authenticated;
grant execute on function public.delete_level(text) to authenticated;
grant execute on function public.report_level(text) to authenticated;
