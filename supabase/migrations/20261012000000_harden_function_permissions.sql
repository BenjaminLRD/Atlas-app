-- ============================================================================
-- Fixes two Supabase security advisor findings.
--
-- 1. is_blocked_between(uuid, uuid) was callable by anyone through the REST API
--    (EXECUTE had been granted to PUBLIC and anon by default), which let a
--    caller check whether one user had blocked another. Only signed-in users
--    need it, because the community RLS policies call it, plus the service
--    role. Revoking from anon alone is not enough: the PUBLIC grant also
--    covers anon, so both are revoked and the needed roles are granted
--    explicitly.
--
-- 2. touch_updated_at() and protect_subscription_tier() had a mutable
--    search_path. They only use built-in functions and the schema-qualified
--    auth.role(), so an empty search_path is safe and cannot be hijacked by a
--    same-named object in another schema.
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.is_blocked_between(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_blocked_between(uuid, uuid) TO authenticated, service_role;

ALTER FUNCTION public.touch_updated_at() SET search_path = '';
ALTER FUNCTION public.protect_subscription_tier() SET search_path = '';
