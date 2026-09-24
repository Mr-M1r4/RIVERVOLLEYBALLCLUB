-- SaaS subscription and payment tracking per club.
create table if not exists public.platform_admins (user_id uuid primary key references auth.users(id) on delete cascade, created_at timestamptz not null default now());
alter table public.platform_admins enable row level security;
drop policy if exists "platform_admins_self" on public.platform_admins;
create policy "platform_admins_self" on public.platform_admins for select to authenticated using (user_id = (select auth.uid()));

create table if not exists public.saas_subscriptions (club_id uuid primary key references public.clubs(id) on delete cascade, monthly_price numeric(12,2) not null default 100000 check (monthly_price >= 0), billing_cycle text not null default 'monthly' check (billing_cycle in ('monthly','quarterly','annual')), started_on date not null default current_date, current_period_start date not null default current_date, current_period_end date not null, status text not null default 'active' check (status in ('trial','active','past_due','suspended','cancelled')), auto_renew boolean not null default true, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
alter table public.saas_subscriptions enable row level security;
drop policy if exists "platform_admins_manage_subscriptions" on public.saas_subscriptions;
create policy "platform_admins_manage_subscriptions" on public.saas_subscriptions for all to authenticated using (exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid()))) with check (exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid())));

create table if not exists public.saas_payments (id uuid primary key default gen_random_uuid(), club_id uuid not null references public.clubs(id) on delete cascade, subscription_period_start date not null, subscription_period_end date not null, amount numeric(12,2) not null check (amount > 0), paid_at timestamptz not null default now(), method text not null default 'transfer', reference text, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now());
alter table public.saas_payments enable row level security;
drop policy if exists "platform_admins_manage_saas_payments" on public.saas_payments;
create policy "platform_admins_manage_saas_payments" on public.saas_payments for all to authenticated using (exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid()))) with check (exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid())));
create index if not exists saas_payments_club_paid_at_idx on public.saas_payments(club_id, paid_at desc);
create index if not exists saas_payments_created_by_idx on public.saas_payments(created_by);
create index if not exists saas_subscriptions_period_end_idx on public.saas_subscriptions(current_period_end);

insert into public.platform_admins(user_id) select p.id from public.profiles p where p.id = '395d072b-a818-4c1b-a162-c7022fc7d141' on conflict do nothing;
insert into public.saas_subscriptions(club_id, monthly_price, billing_cycle, started_on, current_period_start, current_period_end) select c.id, 100000, 'monthly', current_date, current_date, (current_date + interval '1 month')::date - 1 from public.clubs c on conflict (club_id) do nothing;

create or replace function private.touch_saas_subscription() returns trigger language plpgsql security definer set search_path = public, private as $$ begin update public.saas_subscriptions set updated_at = now() where club_id = new.club_id; return new; end; $$;
create or replace function private.apply_saas_payment() returns trigger language plpgsql security definer set search_path = public, private as $$ declare s public.saas_subscriptions%rowtype; next_start date; next_end date; begin select * into s from public.saas_subscriptions where club_id = new.club_id for update; if not found then raise exception 'No existe suscripción para el club'; end if; if new.amount >= s.monthly_price and new.subscription_period_start = s.current_period_start then next_start := s.current_period_end + 1; next_end := case s.billing_cycle when 'annual' then (next_start + interval '1 year')::date - 1 when 'quarterly' then (next_start + interval '3 months')::date - 1 else (next_start + interval '1 month')::date - 1 end; update public.saas_subscriptions set current_period_start=next_start,current_period_end=next_end,status='active',updated_at=now() where club_id=new.club_id; end if; return new; end; $$;
create or replace function private.refresh_saas_billing_status() returns void language sql security definer set search_path = public, private as $$ update public.saas_subscriptions set status = case when status in ('cancelled','suspended') then status when current_period_end < current_date then 'past_due' else status end, updated_at = now() where status in ('trial','active','past_due'); $$;
drop trigger if exists trg_touch_saas_subscription on public.saas_payments;
create trigger trg_touch_saas_subscription after insert on public.saas_payments for each row execute function private.touch_saas_subscription();
drop trigger if exists trg_apply_saas_payment on public.saas_payments;
create trigger trg_apply_saas_payment after insert on public.saas_payments for each row execute function private.apply_saas_payment();
do $$ begin if exists (select 1 from pg_extension where extname = 'pg_cron') then perform cron.unschedule(jobid) from cron.job where jobname = 'river-saas-billing-status'; perform cron.schedule('river-saas-billing-status', '5 8 * * *', 'select private.refresh_saas_billing_status()'); end if; end $$;
grant select, insert, update, delete on public.platform_admins to authenticated;
grant select, insert, update, delete on public.saas_subscriptions to authenticated;
grant select, insert, update, delete on public.saas_payments to authenticated;

drop policy if exists "clubs_member_select" on public.clubs;
drop policy if exists "platform_admins_view_all_clubs" on public.clubs;
create policy "clubs_select" on public.clubs for select to authenticated using (exists (select 1 from public.club_memberships cm where cm.club_id=clubs.id and cm.user_id=(select auth.uid()) and cm.active) or exists (select 1 from public.platform_admins pa where pa.user_id=(select auth.uid())));

create or replace function public.create_club(p_name text, p_slug text) returns uuid language plpgsql security definer set search_path = public, private as $$ declare v_id uuid; begin if private.current_role() <> 'owner' then raise exception 'Solo un owner puede crear clubes'; end if; if trim(coalesce(p_name,''))='' or trim(coalesce(p_slug,''))='' then raise exception 'Nombre y slug son obligatorios'; end if; insert into public.clubs(name,slug) values(trim(p_name),lower(trim(p_slug))) returning id into v_id; insert into public.club_memberships(club_id,user_id,role) values(v_id,(select auth.uid()),'owner'); update public.profiles set active_club_id=v_id where id=(select auth.uid()); insert into public.club_settings(id,club_id,club_name) values(true,v_id,trim(p_name)) on conflict (club_id) do nothing; insert into public.saas_subscriptions(club_id,monthly_price,billing_cycle,started_on,current_period_start,current_period_end) values(v_id,100000,'monthly',current_date,current_date,(current_date + interval '1 month')::date - 1) on conflict (club_id) do nothing; return v_id; end; $$;

alter table public.club_settings drop constraint if exists club_settings_club_id_key;
