-- Performance hardening: cover foreign keys used by tenant membership/profile lookups.
create index if not exists club_memberships_user_id_idx on public.club_memberships(user_id);
create index if not exists profiles_active_club_id_idx on public.profiles(active_club_id);
