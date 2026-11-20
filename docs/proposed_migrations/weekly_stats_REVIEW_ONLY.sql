-- =============================================================================
-- REVIEW ONLY. DO NOT APPLY.
--
-- This file is deliberately outside supabase/migrations/ so that no tool
-- (supabase db push, CI, a teammate) can apply it by accident. Nothing in the
-- Atlas app reads or writes these objects today. The Rankings screen's Real
-- tab shows only the user's own week, computed on the device, until this (or
-- something like it) is reviewed, approved and applied by the project owner.
--
-- Purpose: let members who opt in share weekly totals so a real member
-- leaderboard can exist.
--
-- SECURITY AND INTEGRITY LIMITATIONS (read before approving)
--
-- 1. Spoofing. These figures are reported by the app. A modified client can
--    write any value it likes for its own row. The CHECK constraints below
--    only reject impossible values (negative, absurdly large); they cannot
--    prove a number is true. A leaderboard built on this is fine for a demo
--    or a friendly community, and is NOT cheat-proof or suitable for prizes.
--    A sturdier design computes workouts and minutes on the server from
--    workout_history_records (see the optional function sketch at the end).
--    Steps cannot be verified server-side at all.
-- 2. Privacy. Rows are readable by every signed-in user only when the owner
--    set share = true. The default is false, so nobody appears until they
--    choose to. Turning share off hides the row immediately; deleting the
--    account removes it (ON DELETE CASCADE).
-- 3. Identity. The leaderboard view exposes only the display name and rank
--    that ranked_profiles already makes visible to signed-in users, never an
--    email or profile fields.
-- 4. No rate limit. A client can upsert its row as often as it likes.
-- 5. Weeks are Monday to Sunday and week_start must be a Monday that is not in
--    the future, matching the app.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.weekly_stats (
    user_id          UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    week_start       DATE        NOT NULL,
    workouts         INTEGER     CHECK (workouts BETWEEN 0 AND 50),
    minutes          INTEGER     CHECK (minutes BETWEEN 0 AND 5000),
    volume_kg        NUMERIC     CHECK (volume_kg BETWEEN 0 AND 300000),
    avg_daily_steps  INTEGER     CHECK (avg_daily_steps BETWEEN 0 AND 80000),
    streak_days      INTEGER     CHECK (streak_days BETWEEN 0 AND 5000),
    share            BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, week_start),
    -- Monday only (ISO day of week 1).
    CONSTRAINT weekly_stats_monday CHECK (EXTRACT(ISODOW FROM week_start) = 1)
);

ALTER TABLE public.weekly_stats ENABLE ROW LEVEL SECURITY;

-- Read your own rows, or other members' rows they chose to share.
DROP POLICY IF EXISTS "Read shared or own weekly stats" ON public.weekly_stats;
CREATE POLICY "Read shared or own weekly stats" ON public.weekly_stats
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR share = TRUE);

-- Write only your own rows, and never for a future week.
DROP POLICY IF EXISTS "Write own weekly stats" ON public.weekly_stats;
CREATE POLICY "Write own weekly stats" ON public.weekly_stats
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND week_start <= CURRENT_DATE);

DROP POLICY IF EXISTS "Update own weekly stats" ON public.weekly_stats;
CREATE POLICY "Update own weekly stats" ON public.weekly_stats
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid() AND week_start <= CURRENT_DATE);

DROP POLICY IF EXISTS "Delete own weekly stats" ON public.weekly_stats;
CREATE POLICY "Delete own weekly stats" ON public.weekly_stats
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_weekly_stats_week
    ON public.weekly_stats (week_start DESC, workouts DESC)
    WHERE share = TRUE;

-- Leaderboard view. security_invoker means the caller's own RLS applies, so it
-- can only ever show rows the caller is allowed to read.
CREATE OR REPLACE VIEW public.weekly_leaderboard
WITH (security_invoker = true) AS
SELECT w.week_start,
       w.user_id,
       COALESCE(NULLIF(r.display_name, ''), 'Athlete') AS display_name,
       w.workouts,
       w.minutes,
       w.volume_kg,
       w.avg_daily_steps,
       w.streak_days
FROM public.weekly_stats w
LEFT JOIN public.ranked_profiles r ON r.user_id = w.user_id
WHERE w.share = TRUE;

-- -----------------------------------------------------------------------------
-- OPTIONAL SKETCH (not part of the table above, not reviewed): derive workouts
-- and minutes on the server from synced workout history instead of trusting the
-- client. Needs the workout_history_records columns checked first.
--
-- CREATE OR REPLACE FUNCTION public.recompute_weekly_stats(p_week DATE)
-- RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- BEGIN
--   -- count workouts and sum minutes for auth.uid() between p_week and
--   -- p_week + 7 from workout_history_records, then upsert into weekly_stats.
-- END; $$;
-- -----------------------------------------------------------------------------
