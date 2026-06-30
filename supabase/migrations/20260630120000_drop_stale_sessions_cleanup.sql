-- display_sessions was dropped in 20260624150500_drop_display_sessions.sql
-- but the cron job and cleanup function that referenced it were not removed,
-- causing a "relation does not exist" error every 5 minutes.
--
-- cron.unschedule() raises if the job name doesn't exist (rather than no-op),
-- so guard it: the job may already be gone (e.g. removed by hand), and this
-- migration must stay safely re-runnable.
DO $$
BEGIN
  PERFORM cron.unschedule('cleanup-stale-sessions');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

DROP FUNCTION IF EXISTS public.cleanup_stale_sessions();
