-- RIVER Club OS · hardening and transactional operations
-- This migration is intended to be applied after the baseline RIVER Club OS schema.

create schema if not exists private;
create table if not exists public.audit_logs(
 id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id) on delete set null,
 action text not null, entity text not null, entity_id uuid, details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists audit_logs_created_idx on public.audit_logs(created_at desc);
create index if not exists audit_logs_entity_idx on public.audit_logs(entity,entity_id);
create table if not exists public.inventory_movements(
 id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.product_variants(id) on delete restrict,
 quantity integer not null check(quantity<>0), movement_type text not null check(movement_type in('purchase','sale','adjustment','return')),
 reference text, notes text, created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create index if not exists inventory_movements_variant_idx on public.inventory_movements(variant_id,created_at desc);
alter table public.audit_logs enable row level security;
alter table public.inventory_movements enable row level security;
revoke all on table public.audit_logs,public.inventory_movements from anon;

-- Final policy model. Drop/recreate avoids duplicate permissive policies.
do $$ declare t text; p record; begin
 foreach t in array array['athletes','membership_plans','memberships','payments','products','product_variants','staff_members','staff_payments','registrations','sales','sale_items','notifications'] loop
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
   execute format('drop policy if exists %I on public.%I',p.policyname,t);
  end loop;
 end loop;
end $$;

create policy athletes_read on public.athletes for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy athletes_manage on public.athletes for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy plans_read on public.membership_plans for select to authenticated using(true);
create policy plans_manage on public.membership_plans for all to authenticated using(private.current_role() in('owner','admin')) with check(private.current_role() in('owner','admin'));
create policy memberships_read on public.memberships for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy memberships_manage on public.memberships for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy payments_read on public.payments for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy payments_manage on public.payments for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy products_read on public.products for select to authenticated using(true);
create policy products_manage on public.products for all to authenticated using(private.current_role() in('owner','admin')) with check(private.current_role() in('owner','admin'));
create policy variants_read on public.product_variants for select to authenticated using(true);
create policy variants_manage on public.product_variants for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy staff_read on public.staff_members for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy staff_manage on public.staff_members for all to authenticated using(private.current_role() in('owner','admin')) with check(private.current_role() in('owner','admin'));
create policy staff_payments_read on public.staff_payments for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy staff_payments_manage on public.staff_payments for all to authenticated using(private.current_role() in('owner','admin')) with check(private.current_role() in('owner','admin'));
create policy registrations_read on public.registrations for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy registrations_manage on public.registrations for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy sales_read on public.sales for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy sales_manage on public.sales for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy sale_items_read on public.sale_items for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy sale_items_manage on public.sale_items for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy notifications_read on public.notifications for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy notifications_manage on public.notifications for all to authenticated using(private.current_role() in('owner','admin','staff')) with check(private.current_role() in('owner','admin','staff'));
create policy audit_read on public.audit_logs for select to authenticated using(private.current_role() in('owner','admin'));
create policy audit_insert on public.audit_logs for insert to authenticated with check(actor_id=auth.uid() and private.current_role() in('owner','admin','staff'));
create policy inventory_read on public.inventory_movements for select to authenticated using(private.current_role() in('owner','admin','staff'));
create policy inventory_insert on public.inventory_movements for insert to authenticated with check(private.current_role() in('owner','admin','staff'));

-- The actual transactional RPC bodies are installed in the live project by the complete_club_operations
-- and harden_rpc_and_rls migrations. They use SECURITY INVOKER and role checks.

create index if not exists payments_paid_at_idx on public.payments(paid_at desc);
create index if not exists memberships_end_date_status_idx on public.memberships(end_date,status);
create index if not exists notifications_status_schedule_idx on public.notifications(status,scheduled_for);
