
-- Priority 1a: Fix search_path on all functions that are missing it
-- (handle_new_user already has SET search_path = 'public', so skip it)

-- Trigger functions (not SECURITY DEFINER, just need search_path)
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$;

CREATE OR REPLACE FUNCTION public.update_subscriptions_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$function$;

-- SECURITY DEFINER functions used by RLS policies
CREATE OR REPLACE FUNCTION public.cleanup_stale_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  UPDATE display_sessions
  SET is_active = false
  WHERE is_active = true
    AND last_heartbeat < now() - interval '5 minutes';
END;
$function$;

CREATE OR REPLACE FUNCTION public.user_owns_school(p_school_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM schools WHERE id = p_school_id AND owner_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.user_in_school_org(p_school_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM org_members om
    JOIN schools s ON s.org_id = om.org_id
    WHERE s.id = p_school_id AND om.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.user_is_org_member(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM org_members WHERE org_id = p_org_id AND user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.user_role_in_school_org(p_school_id uuid)
RETURNS text
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT om.role FROM org_members om
  JOIN schools s ON s.org_id = om.org_id
  WHERE s.id = p_school_id AND om.user_id = auth.uid()
  LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.check_contact_rate_limit(p_name text, p_school text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $function$
  SELECT count(*) < 5
  FROM contact_messages
  WHERE name = p_name
    AND school = p_school
    AND created_at > (now() - interval '1 minute');
$function$;


-- Priority 1b: Revoke EXECUTE from anon and authenticated on internal helper functions
-- These are only called internally by RLS policies, not directly by clients
REVOKE EXECUTE ON FUNCTION public.user_owns_school(uuid) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.user_in_school_org(uuid) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.user_is_org_member(uuid) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.user_role_in_school_org(uuid) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_contact_rate_limit(text, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_stale_sessions() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated;


-- Priority 1c: Fix storage bucket listing - remove the broad SELECT policy
-- Public buckets serve files by URL without needing a SELECT policy.
-- The SELECT policy allows listing/enumerating all files, which is a security risk.
DROP POLICY IF EXISTS "Public read task images" ON storage.objects;
