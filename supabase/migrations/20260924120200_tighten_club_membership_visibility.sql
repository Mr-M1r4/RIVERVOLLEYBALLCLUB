drop policy if exists club_memberships_self_select on public.club_memberships;
create policy club_memberships_self_select on public.club_memberships for select to authenticated
using (user_id=(select auth.uid()));
