create or replace function private.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select cm.role
  from public.club_memberships cm
  join public.profiles p on p.active_club_id=cm.club_id
  where cm.user_id=(select auth.uid()) and cm.active and p.id=(select auth.uid())
  limit 1
$$;
revoke all on function private.current_role() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.current_role() to authenticated;

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select private.current_role()
$$;
revoke execute on function public.current_role() from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id,full_name,role,active_club_id)
  values(
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',split_part(coalesce(new.email,''),'@',1)),
    'staff',
    '00000000-0000-0000-0000-000000000001'
  )
  on conflict (id) do nothing;
  insert into public.club_memberships(club_id,user_id,role)
  values('00000000-0000-0000-0000-000000000001',new.id,'staff')
  on conflict (club_id,user_id) do nothing;
  return new;
end
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;