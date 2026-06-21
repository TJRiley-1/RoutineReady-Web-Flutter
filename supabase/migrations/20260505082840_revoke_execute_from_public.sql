
-- Revoke EXECUTE from PUBLIC (which anon and authenticated inherit from)
REVOKE EXECUTE ON FUNCTION public.user_owns_school(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.user_in_school_org(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.user_is_org_member(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.user_role_in_school_org(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_contact_rate_limit(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cleanup_stale_sessions() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
