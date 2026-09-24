alter table public.club_settings drop constraint if exists club_settings_pkey;
alter table public.club_settings add constraint club_settings_pkey primary key (club_id);
