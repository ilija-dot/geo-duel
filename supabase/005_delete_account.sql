-- Geo Duel update 5: players can delete their account and all their data.
-- Run once after 004_accounts.sql (safe to re-run).
-- Deleting the login removes the player, their duels and their levels (via "on delete cascade").

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
