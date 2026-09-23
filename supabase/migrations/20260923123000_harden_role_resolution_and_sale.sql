-- Harden role resolution and inventory sale authorization.
-- Authenticated users without a profile must not inherit an operational role.
create or replace function private.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

revoke execute on function public.current_role() from public, anon, authenticated;

-- Sale is an atomic operation, but does not need SECURITY DEFINER:
-- its inserts/updates are authorized by the existing RLS policies.
alter function public.create_sale(uuid,uuid,integer,text,text) security invoker;
alter function public.create_sale(uuid,uuid,integer,text,text) set search_path = public, private;
revoke execute on function public.create_sale(uuid,uuid,integer,text,text) from public, anon;
grant execute on function public.create_sale(uuid,uuid,integer,text,text) to authenticated;
