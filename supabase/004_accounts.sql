-- Geo Duel update 4: email + password accounts.
-- Run once after 003_difficulty_levels.sql (safe to re-run).
--
-- Accounts use Supabase's own email login, so no new tables are needed:
--   * A guest (anonymous) player adds an email + password. Supabase upgrades the same
--     account, so the player ID, duels, levels and avatar stay the same.
--   * Logging in on another device signs in to that same account and the same player.
-- Supabase setting needed: Authentication -> Sign In / Providers -> Email -> "Confirm email" OFF
-- (Supabase's built-in mailer only sends to project team members; add your own SMTP later
--  if you want confirmation and password-reset emails.)

-- Clean up an earlier username/password attempt (never used by players).
drop function if exists public.set_login(text, text);
drop function if exists public.login(text, text);
drop function if exists public.logout();
drop table if exists public.player_logins;
drop index if exists public.players_username_idx;
alter table public.players drop column if exists username;
alter table public.players drop column if exists password_hash;
alter table public.players drop column if exists failed_logins;
alter table public.players drop column if exists locked_until;

create or replace function public.my_player_id()
returns text language sql stable security definer set search_path = public as $$
  select id from public.players where user_id = auth.uid()
$$;

-- Your player (after logging in on a new device). null if this account has no player yet.
create or replace function public.my_profile()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('id', id, 'nickname', nickname, 'avatar', avatar)
  from public.players where user_id = auth.uid()
$$;
revoke execute on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;
