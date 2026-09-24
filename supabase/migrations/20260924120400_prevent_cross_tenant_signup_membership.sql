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
  return new;
end
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
