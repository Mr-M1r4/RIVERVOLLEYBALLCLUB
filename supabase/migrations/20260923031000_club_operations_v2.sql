-- RIVER Club OS: teams, attendance, arrears, reports and settings
-- Applied to production through Supabase migration API.
-- This marker keeps the repository migration history aligned with the live schema.

create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 min_age integer,
 max_age integer,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.teams (
 id uuid primary key default gen_random_uuid(),
 name text not null unique,
 category_id uuid references public.categories(id) on delete set null,
 coach_id uuid references public.staff_members(id) on delete set null,
 training_schedule text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.athletes add column if not exists category_id uuid references public.categories(id) on delete set null;
alter table public.athletes add column if not exists team_id uuid references public.teams(id) on delete set null;
create table if not exists public.training_sessions (
 id uuid primary key default gen_random_uuid(),
 team_id uuid references public.teams(id) on delete set null,
 coach_id uuid references public.staff_members(id) on delete set null,
 session_date date not null,
 start_time time,
 end_time time,
 location text,
 notes text,
 status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
 created_at timestamptz not null default now()
);
create table if not exists public.attendance (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.training_sessions(id) on delete cascade,
 athlete_id uuid not null references public.athletes(id) on delete cascade,
 status text not null check (status in ('present','absent','late','excused')),
 notes text,
 marked_at timestamptz not null default now(),
 marked_by uuid references auth.users(id) on delete set null,
 unique(session_id, athlete_id)
);
create table if not exists public.club_settings (
 id boolean primary key default true check(id=true),
 club_name text not null default 'RIVER Volleyball Club',
 currency text not null default 'COP',
 locale text not null default 'es-CO',
 reminder_days integer not null default 7 check(reminder_days between 0 and 30),
 payment_methods jsonb not null default '["cash","transfer","card","other"]'::jsonb,
 communication_templates jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id) on delete set null
);
insert into public.club_settings(id) values(true) on conflict(id) do nothing;
-- RLS policies and the security_invoker arrears view are maintained in the live migration.
