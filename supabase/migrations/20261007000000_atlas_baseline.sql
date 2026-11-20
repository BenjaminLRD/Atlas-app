-- ============================================================================
-- Atlas baseline schema: accounts and the data the app syncs.
--
-- Replaces the earlier scripts now in supabase/archive/, which collided on
-- version numbers and defined the same tables twice with different columns.
-- Safe to run on a fresh project or one where those scripts were run by hand:
-- synced data lives in new tables, and profiles is only extended.
--
-- Synced tables keep the app's own JSON in `data`, plus the columns needed
-- for ordering, so model changes in the app do not need a migration.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Shared helper: keep updated_at current.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Profiles: one row per account, created automatically at sign-up.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT NOT NULL DEFAULT '',
    subscription_tier TEXT NOT NULL DEFAULT 'Free',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'Free';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW());

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are readable by their owner" ON public.profiles;
CREATE POLICY "Profiles are readable by their owner"
    ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles are insertable by their owner" ON public.profiles;
CREATE POLICY "Profiles are insertable by their owner"
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles are updatable by their owner" ON public.profiles;
CREATE POLICY "Profiles are updatable by their owner"
    ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP TRIGGER IF EXISTS profiles_touch_updated_at ON public.profiles;
CREATE TRIGGER profiles_touch_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data ->> 'display_name', '')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Synced app data. Every row belongs to one user; RLS limits each user to
-- their own rows. Deleting the auth user deletes all of it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.workout_session_records (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    started_at TIMESTAMPTZ,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, id)
);

CREATE TABLE IF NOT EXISTS public.workout_history_records (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    completed_at TIMESTAMPTZ,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, id)
);

CREATE TABLE IF NOT EXISTS public.nutrition_day_records (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (user_id, log_date)
);

CREATE TABLE IF NOT EXISTS public.fitness_goal_records (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_workout_session_records_started
    ON public.workout_session_records (user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_history_records_completed
    ON public.workout_history_records (user_id, completed_at DESC);

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'workout_session_records',
        'workout_history_records',
        'nutrition_day_records',
        'fitness_goal_records'
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS "Owner can manage rows" ON public.%I', t);
        EXECUTE format(
            'CREATE POLICY "Owner can manage rows" ON public.%I FOR ALL '
            'USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)',
            t
        );
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', t || '_touch_updated_at', t);
        EXECUTE format(
            'CREATE TRIGGER %I BEFORE UPDATE ON public.%I '
            'FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at()',
            t || '_touch_updated_at', t
        );
    END LOOP;
END;
$$;
