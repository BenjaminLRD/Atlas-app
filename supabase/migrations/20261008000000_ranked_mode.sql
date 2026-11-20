-- ============================================================================
-- Ranked mode: server-computed rank from verified milestones.
--
-- The app never writes rank. The ranked-sync Edge Function evaluates
-- milestones from the user's synced workouts and cardio sessions and records
-- claims; the database derives each user's rank from approved claims only.
-- Milestones at the top levels need a video, approved by a reviewer.
-- Milestone definitions: supabase/functions/_shared/ranked_milestones.json.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Cardio sessions sync (needed for the Cardio stat).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cardio_session_records (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    started_at TIMESTAMPTZ,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, id)
);

ALTER TABLE public.cardio_session_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can manage rows" ON public.cardio_session_records;
CREATE POLICY "Owner can manage rows" ON public.cardio_session_records FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP TRIGGER IF EXISTS cardio_session_records_touch_updated_at ON public.cardio_session_records;
CREATE TRIGGER cardio_session_records_touch_updated_at
    BEFORE UPDATE ON public.cardio_session_records
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- How each stat's level is derived from its milestones (mirrors "rule" in
-- ranked_milestones.json): best = best milestone level; second_best = the
-- level must be reached on two milestones.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ranked_stat_rules (
    stat_id TEXT PRIMARY KEY,
    rule TEXT NOT NULL CHECK (rule IN ('best', 'second_best'))
);
INSERT INTO public.ranked_stat_rules (stat_id, rule) VALUES
    ('strength', 'second_best'),
    ('endurance', 'best'),
    ('cardio', 'best'),
    ('consistency', 'best')
ON CONFLICT (stat_id) DO UPDATE SET rule = EXCLUDED.rule;
ALTER TABLE public.ranked_stat_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone signed in can read stat rules" ON public.ranked_stat_rules;
CREATE POLICY "Anyone signed in can read stat rules" ON public.ranked_stat_rules
    FOR SELECT TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Milestone claims: one row per user, milestone and level.
-- status: approved | needs_video | pending_review | rejected
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ranked_claims (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    milestone_id TEXT NOT NULL,
    stat_id TEXT NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 5),
    value NUMERIC,
    status TEXT NOT NULL CHECK (status IN ('approved', 'needs_video', 'pending_review', 'rejected')),
    video_path TEXT,
    reviewer_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, milestone_id, level)
);

ALTER TABLE public.ranked_claims ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own claims" ON public.ranked_claims;
CREATE POLICY "Users can view their own claims" ON public.ranked_claims
    FOR SELECT USING (auth.uid() = user_id);
-- No insert/update/delete policies: only the service role writes claims.

DROP TRIGGER IF EXISTS ranked_claims_touch_updated_at ON public.ranked_claims;
CREATE TRIGGER ranked_claims_touch_updated_at
    BEFORE UPDATE ON public.ranked_claims
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Public rank per user (leaderboards read this). Derived, never written by
-- users.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ranked_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT '',
    stat_levels JSONB NOT NULL DEFAULT '{}'::jsonb,
    points INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE public.ranked_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Signed-in users can view ranks" ON public.ranked_profiles;
CREATE POLICY "Signed-in users can view ranks" ON public.ranked_profiles
    FOR SELECT TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_ranked_profiles_points
    ON public.ranked_profiles (points DESC, updated_at);

-- Recomputes one user's ranked profile from their approved claims.
CREATE OR REPLACE FUNCTION public.recompute_ranked_profile(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_levels JSONB;
    v_points INTEGER;
BEGIN
    WITH best AS (
        SELECT stat_id, milestone_id, MAX(level) AS lvl
        FROM public.ranked_claims
        WHERE user_id = p_user_id AND status = 'approved'
        GROUP BY stat_id, milestone_id
    ), ordered AS (
        SELECT stat_id, lvl,
               ROW_NUMBER() OVER (PARTITION BY stat_id ORDER BY lvl DESC) AS rn
        FROM best
    ), stats AS (
        SELECT o.stat_id,
               COALESCE(MAX(o.lvl) FILTER (
                   WHERE o.rn = CASE WHEN r.rule = 'second_best' THEN 2 ELSE 1 END
               ), 0) AS lvl
        FROM ordered o
        LEFT JOIN public.ranked_stat_rules r USING (stat_id)
        GROUP BY o.stat_id
    )
    SELECT COALESCE(jsonb_object_agg(stat_id, lvl), '{}'::jsonb),
           COALESCE(SUM(lvl), 0)
    INTO v_levels, v_points
    FROM stats;

    INSERT INTO public.ranked_profiles (user_id, display_name, stat_levels, points, updated_at)
    VALUES (
        p_user_id,
        COALESCE((SELECT NULLIF(full_name, '') FROM public.profiles WHERE id = p_user_id), ''),
        v_levels,
        v_points,
        TIMEZONE('utc'::text, NOW())
    )
    ON CONFLICT (user_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        stat_levels = EXCLUDED.stat_levels,
        points = EXCLUDED.points,
        updated_at = EXCLUDED.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.ranked_claims_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.recompute_ranked_profile(COALESCE(NEW.user_id, OLD.user_id));
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS ranked_claims_recompute ON public.ranked_claims;
CREATE TRIGGER ranked_claims_recompute
    AFTER INSERT OR UPDATE OR DELETE ON public.ranked_claims
    FOR EACH ROW EXECUTE FUNCTION public.ranked_claims_changed();

-- Records claims from the ranked-sync function. A claim that is already
-- approved, under review or rejected keeps its status; only its value updates.
CREATE OR REPLACE FUNCTION public.upsert_ranked_claims(p_user_id UUID, p_claims JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.ranked_claims (user_id, milestone_id, stat_id, level, value, status)
    SELECT p_user_id,
           c ->> 'milestone_id',
           c ->> 'stat_id',
           (c ->> 'level')::SMALLINT,
           (c ->> 'value')::NUMERIC,
           c ->> 'status'
    FROM jsonb_array_elements(p_claims) AS c
    ON CONFLICT (user_id, milestone_id, level) DO UPDATE SET
        value = EXCLUDED.value,
        status = CASE
            WHEN public.ranked_claims.status IN ('approved', 'pending_review', 'rejected')
                THEN public.ranked_claims.status
            ELSE EXCLUDED.status
        END;
END;
$$;

REVOKE ALL ON FUNCTION public.recompute_ranked_profile(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.upsert_ranked_claims(UUID, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_ranked_profile(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.upsert_ranked_claims(UUID, JSONB) TO service_role;

-- Reviewers work through this queue in the dashboard: watch the video, then
-- set status to 'approved' or 'rejected' (with reviewer_note). Rank updates
-- automatically.
CREATE OR REPLACE VIEW public.ranked_review_queue
WITH (security_invoker = true) AS
SELECT c.user_id, p.display_name, c.milestone_id, c.level, c.value,
       c.video_path, c.updated_at AS submitted_at
FROM public.ranked_claims c
LEFT JOIN public.ranked_profiles p USING (user_id)
WHERE c.status = 'pending_review'
ORDER BY c.updated_at;

-- ---------------------------------------------------------------------------
-- Proof videos: private bucket, one folder per user (<user id>/...).
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('ranked-proofs', 'ranked-proofs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users upload their own ranked proofs" ON storage.objects;
CREATE POLICY "Users upload their own ranked proofs" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'ranked-proofs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users view their own ranked proofs" ON storage.objects;
CREATE POLICY "Users view their own ranked proofs" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'ranked-proofs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
