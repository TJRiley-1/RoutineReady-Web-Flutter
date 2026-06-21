
-- RLS policy expressions execute with the privileges of the querying role, so
-- any function referenced inside a policy must be EXECUTE-able by that role —
-- even SECURITY DEFINER functions. The 20260505082804_fix_security_advisors
-- migration revoked EXECUTE from authenticated/anon on these helpers, which
-- broke every RLS policy that calls them (42501 permission denied). Restore
-- EXECUTE to the calling roles. These helpers only report facts about the
-- current auth.uid(), so this leaks nothing.

GRANT EXECUTE ON FUNCTION public.user_is_org_member(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_in_school_org(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_owns_school(uuid)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_role_in_school_org(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_contact_rate_limit(text,text) TO anon, authenticated;
