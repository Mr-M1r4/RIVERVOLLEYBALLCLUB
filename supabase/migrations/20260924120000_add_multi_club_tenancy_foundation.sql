create extension if not exists pgcrypto;

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.clubs (id,name,slug)
values ('00000000-0000-0000-0000-000000000001','RIVER Volleyball Club','river-volleyball-club')
on conflict (id) do nothing;

alter table public.profiles add column if not exists active_club_id uuid;
update public.profiles set active_club_id='00000000-0000-0000-0000-000000000001' where active_club_id is null;
alter table public.profiles alter column active_club_id set not null;
alter table public.profiles drop constraint if exists profiles_active_club_id_fkey;
alter table public.profiles add constraint profiles_active_club_id_fkey foreign key (active_club_id) references public.clubs(id);

create table if not exists public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.user_role not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (club_id,user_id)
);

insert into public.club_memberships (club_id,user_id,role)
select p.active_club_id,p.id,p.role from public.profiles p
on conflict (club_id,user_id) do update set role=excluded.role, active=true;

create or replace function private.current_club_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select active_club_id from public.profiles where id=(select auth.uid())
$$;
revoke all on function private.current_club_id() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.current_club_id() to authenticated;

alter table public.club_settings add column if not exists club_id uuid;
update public.club_settings set club_id='00000000-0000-0000-0000-000000000001' where club_id is null;
alter table public.club_settings alter column club_id set not null;
alter table public.club_settings drop constraint if exists club_settings_club_id_key;
alter table public.club_settings add constraint club_settings_club_id_key unique (club_id);
alter table public.club_settings drop constraint if exists club_settings_id_check;
alter table public.club_settings alter column id set default true;

do $$
declare t text;
begin
  foreach t in array array[
    'athletes','attendance','audit_logs','categories','inventory_movements',
    'membership_plans','memberships','notifications','payments',
    'product_variants','products','registrations','sale_items','sales',
    'staff_members','staff_payments','teams','training_sessions'
  ] loop
    execute format('alter table public.%I add column if not exists club_id uuid',t);
    execute format('update public.%I set club_id=''00000000-0000-0000-0000-000000000001'' where club_id is null',t);
    execute format('alter table public.%I alter column club_id set not null',t);
    execute format('alter table public.%I drop constraint if exists %I',t,t||'_club_id_fkey');
    execute format('alter table public.%I add constraint %I foreign key (club_id) references public.clubs(id)',t,t||'_club_id_fkey');
    execute format('create index if not exists %I on public.%I (club_id)',t||'_club_id_idx',t);
    execute format('alter table public.%I alter column club_id set default private.current_club_id()',t);
  end loop;
end $$;

alter table public.club_settings alter column club_id set default private.current_club_id();

alter table public.clubs enable row level security;
alter table public.club_memberships enable row level security;

drop policy if exists clubs_member_select on public.clubs;
create policy clubs_member_select on public.clubs for select to authenticated
using (exists (select 1 from public.club_memberships cm where cm.club_id=clubs.id and cm.user_id=(select auth.uid()) and cm.active));

drop policy if exists club_memberships_self_select on public.club_memberships;
create policy club_memberships_self_select on public.club_memberships for select to authenticated
using (user_id=(select auth.uid()) or club_id=(select private.current_club_id()));

do $$
declare t text;
begin
  foreach t in array array[
    'athletes','attendance','audit_logs','categories','club_settings','inventory_movements',
    'membership_plans','memberships','notifications','payments',
    'product_variants','products','registrations','sale_items','sales',
    'staff_members','staff_payments','teams','training_sessions'
  ] loop
    execute format('drop policy if exists tenant_isolation on public.%I',t);
    execute format('create policy tenant_isolation on public.%I as restrictive for all to authenticated using (club_id=(select private.current_club_id())) with check (club_id=(select private.current_club_id()))',t);
  end loop;
end $$;

create or replace function public.switch_club(p_club_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if not exists (
    select 1 from public.club_memberships
    where club_id=p_club_id and user_id=(select auth.uid()) and active
  ) then
    raise exception 'No tienes acceso a este club';
  end if;
  update public.profiles set active_club_id=p_club_id where id=(select auth.uid());
end
$$;
revoke all on function public.switch_club(uuid) from public, anon;
grant execute on function public.switch_club(uuid) to authenticated;

create or replace function public.create_club(p_name text, p_slug text)
returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare v_id uuid;
begin
  if private.current_role() <> 'owner' then
    raise exception 'Solo un owner puede crear clubes';
  end if;
  if trim(coalesce(p_name,''))='' or trim(coalesce(p_slug,''))='' then
    raise exception 'Nombre y slug son obligatorios';
  end if;
  insert into public.clubs(name,slug) values(trim(p_name),lower(trim(p_slug))) returning id into v_id;
  insert into public.club_memberships(club_id,user_id,role) values(v_id,(select auth.uid()),'owner');
  update public.profiles set active_club_id=v_id where id=(select auth.uid());
  insert into public.club_settings(id,club_id,club_name)
  values(true,v_id,trim(p_name))
  on conflict (club_id) do nothing;
  return v_id;
end
$$;
revoke all on function public.create_club(text,text) from public, anon;
grant execute on function public.create_club(text,text) to authenticated;
grant select on public.clubs, public.club_memberships to authenticated;