-- Geo Duel update 2: avatars and the global leaderboard.
-- Run once after schema.sql (safe to re-run).

-- ---------------------------------------------------------------- avatars

alter table public.players add column if not exists avatar jsonb not null default '{}'::jsonb;
grant select (avatar) on public.players to authenticated;

-- Saves your avatar. It's a small set of part numbers, e.g. {"skin":2,"hair":3,...}.
create or replace function public.set_avatar(av jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  k text;
  v jsonb;
begin
  if public.my_player_id() is null then
    raise exception 'not registered';
  end if;
  if jsonb_typeof(av) <> 'object' then
    raise exception 'bad avatar';
  end if;
  for k, v in select * from jsonb_each(av) loop
    if k not in ('skin', 'hair', 'hair_color', 'eyes', 'mouth', 'acc', 'bg')
       or jsonb_typeof(v) <> 'number' or (v #>> '{}')::numeric not between 0 and 50 then
      raise exception 'bad avatar';
    end if;
  end loop;
  update public.players set avatar = av where user_id = auth.uid();
end;
$$;
revoke execute on function public.set_avatar(jsonb) from public, anon;
grant execute on function public.set_avatar(jsonb) to authenticated;

-- Duels now also carry the opponent's avatar.
create or replace function public._match_view(m public.matches, me text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id',              m.id,
    'opponent_id',     case when m.p1 = me then m.p2 else m.p1 end,
    'opponent_name',   op.nickname,
    'opponent_avatar', op.avatar,
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

-- ---------------------------------------------------------------- leaderboard

create index if not exists matches_finished_idx on public.matches (finished_at) where finished_at is not null;

-- period: 'week' (since Monday), 'last_week', or 'all'.
-- Ranked by wins, then total points. To stop two friends farming wins off each other,
-- at most 3 wins against the same opponent count per week.
-- Returns {"rows": [top 50], "me": your row or null}.
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
      from public.matches where finished_at >= since and finished_at < before
      union all
      select p2, p1, (p2_score > p1_score)::int, p2_score, finished_at
      from public.matches where finished_at >= since and finished_at < before
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
revoke execute on function public.leaderboard(text) from public, anon;
grant execute on function public.leaderboard(text) to authenticated;
