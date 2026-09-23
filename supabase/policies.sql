-- RIVER Club OS · Production RLS
-- Baseline tables are created in the Supabase project. This file documents the final access model.
-- Authorization is enforced by RLS; UI visibility is not a security boundary.

create schema if not exists private;

do $$
declare t text;
begin
  foreach t in array array[
    'athletes','membership_plans','memberships','payments','products','product_variants',
    'staff_members','staff_payments','registrations','sales','sale_items','notifications',
    'audit_logs','inventory_movements'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on table public.%I from anon',t);
  end loop;
end $$;

-- Role helper lives outside the exposed API schema and has a fixed search_path.
create or replace function private.current_role()
returns public.user_role
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select role from public.profiles where id=auth.uid()), 'staff'::public.user_role)
$$;
revoke all on function private.current_role() from public,anon,authenticated;
grant execute on function private.current_role() to authenticated;

-- The transactional RPCs are SECURITY INVOKER. RLS therefore remains active inside them.
-- See the corresponding migration for their definitions.
