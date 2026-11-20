-- ============================================================================
-- FitForge Supabase Authentication & User Identity System Migration (Phase B.3)
-- Production Authentication, Profiles, Fitness Profiles & Strict Row Level Security
-- ============================================================================

-- 1. Create Profiles Table if not exists
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    username TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create Fitness Profiles Table if not exists
CREATE TABLE IF NOT EXISTS public.fitness_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    age INTEGER,
    gender TEXT,
    height TEXT,
    weight TEXT,
    fitness_goal TEXT,
    experience_level TEXT,
    equipment JSONB DEFAULT '[]'::jsonb,
    preferred_days JSONB DEFAULT '[]'::jsonb,
    diet_preference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Enable Row Level Security (RLS) on all user-owned tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fitness_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_memory ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for Profiles
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id OR auth.uid() = user_id)
    WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own" ON public.profiles
    FOR DELETE USING (auth.uid() = id OR auth.uid() = user_id);

-- 5. RLS Policies for Fitness Profiles
DROP POLICY IF EXISTS "fitness_profiles_select_own" ON public.fitness_profiles;
CREATE POLICY "fitness_profiles_select_own" ON public.fitness_profiles
    FOR SELECT USING (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "fitness_profiles_insert_own" ON public.fitness_profiles;
CREATE POLICY "fitness_profiles_insert_own" ON public.fitness_profiles
    FOR INSERT WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "fitness_profiles_update_own" ON public.fitness_profiles;
CREATE POLICY "fitness_profiles_update_own" ON public.fitness_profiles
    FOR UPDATE USING (auth.uid() = id OR auth.uid() = user_id)
    WITH CHECK (auth.uid() = id OR auth.uid() = user_id);

DROP POLICY IF EXISTS "fitness_profiles_delete_own" ON public.fitness_profiles;
CREATE POLICY "fitness_profiles_delete_own" ON public.fitness_profiles
    FOR DELETE USING (auth.uid() = id OR auth.uid() = user_id);

-- 6. RLS Policies for Workout Sessions
DROP POLICY IF EXISTS "workout_sessions_select_own" ON public.workout_sessions;
CREATE POLICY "workout_sessions_select_own" ON public.workout_sessions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "workout_sessions_insert_own" ON public.workout_sessions;
CREATE POLICY "workout_sessions_insert_own" ON public.workout_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "workout_sessions_update_own" ON public.workout_sessions;
CREATE POLICY "workout_sessions_update_own" ON public.workout_sessions
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "workout_sessions_delete_own" ON public.workout_sessions;
CREATE POLICY "workout_sessions_delete_own" ON public.workout_sessions
    FOR DELETE USING (auth.uid() = user_id);

-- 7. RLS Policies for Nutrition Logs
DROP POLICY IF EXISTS "nutrition_logs_select_own" ON public.nutrition_logs;
CREATE POLICY "nutrition_logs_select_own" ON public.nutrition_logs
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "nutrition_logs_insert_own" ON public.nutrition_logs;
CREATE POLICY "nutrition_logs_insert_own" ON public.nutrition_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "nutrition_logs_update_own" ON public.nutrition_logs;
CREATE POLICY "nutrition_logs_update_own" ON public.nutrition_logs
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "nutrition_logs_delete_own" ON public.nutrition_logs;
CREATE POLICY "nutrition_logs_delete_own" ON public.nutrition_logs
    FOR DELETE USING (auth.uid() = user_id);

-- 8. RLS Policies for AI Memory
DROP POLICY IF EXISTS "ai_memory_select_own" ON public.ai_memory;
CREATE POLICY "ai_memory_select_own" ON public.ai_memory
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_memory_insert_own" ON public.ai_memory;
CREATE POLICY "ai_memory_insert_own" ON public.ai_memory
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_memory_update_own" ON public.ai_memory;
CREATE POLICY "ai_memory_update_own" ON public.ai_memory
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ai_memory_delete_own" ON public.ai_memory;
CREATE POLICY "ai_memory_delete_own" ON public.ai_memory
    FOR DELETE USING (auth.uid() = user_id);

-- 9. Automatic Profile Creation Trigger on Auth Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, user_id, email, username, avatar_url, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.fitness_profiles (id, user_id, age, gender, height, weight, fitness_goal, experience_level, equipment, preferred_days, diet_preference, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.id,
        25,
        'male',
        '175',
        '70',
        'build_muscle',
        'intermediate',
        '["Barbell", "Dumbbells", "Bench"]'::jsonb,
        '["Mon", "Wed", "Fri"]'::jsonb,
        'standard',
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
