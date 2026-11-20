-- ============================================================================
-- AI usage quotas for the ai-proxy Edge Function, and protection of
-- profiles.subscription_tier so users cannot grant themselves Pro.
-- ============================================================================

-- Daily AI request counters, one row per user, day (UTC) and feature.
CREATE TABLE IF NOT EXISTS public.ai_usage (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL DEFAULT (TIMEZONE('utc'::text, NOW()))::date,
    feature TEXT NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date, feature)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own AI usage" ON public.ai_usage;
CREATE POLICY "Users can view their own AI usage"
    ON public.ai_usage FOR SELECT
    USING (auth.uid() = user_id);
-- No insert/update/delete policies: only the service role writes counters.

-- Atomically counts one request. Returns FALSE once the day's limit is reached.
CREATE OR REPLACE FUNCTION public.consume_ai_quota(
    p_user_id UUID,
    p_feature TEXT,
    p_limit INTEGER
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    INSERT INTO public.ai_usage (user_id, usage_date, feature, request_count)
    VALUES (p_user_id, (TIMEZONE('utc'::text, NOW()))::date, p_feature, 1)
    ON CONFLICT (user_id, usage_date, feature)
    DO UPDATE SET request_count = public.ai_usage.request_count + 1
        WHERE public.ai_usage.request_count < p_limit
    RETURNING request_count INTO v_count;

    RETURN v_count IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_ai_quota(UUID, TEXT, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_ai_quota(UUID, TEXT, INTEGER) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_quota(UUID, TEXT, INTEGER) TO service_role;

-- The app upserts the whole profile row, including subscription_tier. Ignore
-- tier changes that come from end users; only the service role (billing
-- webhooks, admin tools) may change it.
CREATE OR REPLACE FUNCTION public.protect_subscription_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF COALESCE(auth.role(), '') IN ('anon', 'authenticated') THEN
        IF TG_OP = 'INSERT' THEN
            NEW.subscription_tier := 'Free';
        ELSIF NEW.subscription_tier IS DISTINCT FROM OLD.subscription_tier THEN
            NEW.subscription_tier := OLD.subscription_tier;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_subscription_tier ON public.profiles;
CREATE TRIGGER protect_subscription_tier
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_subscription_tier();
