-- RIVER Club OS · automatic reminder scheduler
create extension if not exists pg_cron with schema pg_catalog;
select cron.unschedule(jobid) from cron.job where jobname='river-membership-reminders';
select cron.schedule('river-membership-reminders','0 8 * * *',$$select public.queue_membership_reminders();$$);
