-- Store the expected unit quantity for staff rates and the quantity used in each staff payment.
alter table public.staff_members
  add column if not exists rate_quantity numeric(12,2) not null default 1
  check (rate_quantity > 0);

alter table public.staff_payments
  add column if not exists quantity numeric(12,2) not null default 1
  check (quantity > 0);

create or replace function public.record_staff_payment(
  p_staff_id uuid,
  p_amount numeric,
  p_period_start date,
  p_period_end date,
  p_concept text,
  p_method text default 'cash',
  p_reference text default null,
  p_quantity numeric default 1
) returns uuid
language plpgsql
set search_path = public, private
as $$
declare v_id uuid;
begin
  if private.current_role() not in ('owner','admin') then raise exception 'not authorized'; end if;
  if p_quantity <= 0 then raise exception 'quantity must be greater than zero'; end if;
  insert into public.staff_payments(staff_id,amount,quantity,period_start,period_end,concept,method,reference,status,paid_at)
  values(p_staff_id,p_amount,p_quantity,p_period_start,p_period_end,p_concept,p_method,p_reference,'confirmed',now())
  returning id into v_id;
  insert into public.audit_logs(actor_id,action,entity,entity_id,details)
  values(auth.uid(),'create','staff_payment',v_id,jsonb_build_object('staff_id',p_staff_id,'amount',p_amount,'quantity',p_quantity));
  return v_id;
end $$;

revoke execute on function public.record_staff_payment(uuid,numeric,date,date,text,text,text,numeric) from public,anon;
grant execute on function public.record_staff_payment(uuid,numeric,date,date,text,text,text,numeric) to authenticated;
