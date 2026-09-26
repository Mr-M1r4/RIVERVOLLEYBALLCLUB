-- Allow SaaS platform admins to create clubs from the Club OS.
-- The live function is also updated by this migration; no service-role key is required.
create or replace function public.create_club(p_name text, p_slug text)
returns uuid
language plpgsql
security definer
set search_path to 'public','private'
as $function$
declare v_id uuid; v_uid uuid;
begin
  v_uid := (select auth.uid());
  if v_uid is null then raise exception 'Sesión requerida'; end if;
  if not (
    private.current_role() = 'owner'
    or exists (select 1 from public.platform_admins where user_id=v_uid)
  ) then
    raise exception 'No tienes permisos para crear clubes';
  end if;
  if trim(coalesce(p_name,''))='' or trim(coalesce(p_slug,''))='' then
    raise exception 'Nombre y slug son obligatorios';
  end if;
  insert into public.clubs(name,slug) values(trim(p_name),lower(trim(p_slug))) returning id into v_id;
  insert into public.club_memberships(club_id,user_id,role) values(v_id,v_uid,'owner');
  update public.profiles set active_club_id=v_id where id=v_uid;
  insert into public.club_settings(id,club_id,club_name) values(true,v_id,trim(p_name))
  on conflict (club_id) do nothing;
  insert into public.saas_subscriptions(club_id,monthly_price,billing_cycle,started_on,current_period_start,current_period_end)
  values(v_id,100000,'monthly',current_date,current_date,(current_date + interval '1 month')::date - 1)
  on conflict (club_id) do nothing;
  return v_id;
end
$function$;
