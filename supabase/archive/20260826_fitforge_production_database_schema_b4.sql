-- ============================================================================
-- FitForge Production Database Architecture Migration (Phase B.4)
-- PostgreSQL Schema, Relationships, Row Level Security (RLS) & Performance Indexes
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. USER DOMAIN TABLES
-- ============================================================================

-- User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fitness Profiles Table (Feeds AI Coach, Workout Generator, Nutrition)
CREATE TABLE IF NOT EXISTS public.fitness_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    age INTEGER,
    height TEXT,
    weight TEXT,
    goal TEXT,
    experience_level TEXT,
    equipment JSONB NOT NULL DEFAULT '[]'::jsonb,
    injuries JSONB NOT NULL DEFAULT '[]'::jsonb,
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. WORKOUT DOMAIN TABLES
-- ============================================================================

-- Workout Sessions Table
CREATE TABLE IF NOT EXISTS public.workout_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    total_volume NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    calories_burned NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    xp_earned INTEGER NOT NULL DEFAULT 0,
    personal_records JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Workout Exercises Table (Stores Real Execution Sets & Volume)
CREATE TABLE IF NOT EXISTS public.workout_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    muscle_group TEXT,
    sets JSONB NOT NULL DEFAULT '[]'::jsonb,
    volume NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    max_weight NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. NUTRITION DOMAIN TABLES
-- ============================================================================

-- Nutrition Logs Table
CREATE TABLE IF NOT EXISTS public.nutrition_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_nutrition_logs_user_date UNIQUE (user_id, date)
);

-- Meal Entries Table (Normalized Food Items Logged per Nutrition Record)
CREATE TABLE IF NOT EXISTS public.meal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nutrition_log_id UUID NOT NULL REFERENCES public.nutrition_logs(id) ON DELETE CASCADE,
    meal_type TEXT NOT NULL,
    food_name TEXT NOT NULL,
    calories NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    protein NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    carbs NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    fat NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    quantity NUMERIC(8, 2) NOT NULL DEFAULT 1.00,
    source TEXT NOT NULL DEFAULT 'manual', -- 'ai_vision', 'barcode', 'manual'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 4. AI COACH & MEMORY DOMAIN TABLES
-- ============================================================================

-- AI Memory Table (Persistent Personal Coach Memory)
CREATE TABLE IF NOT EXISTS public.ai_memory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation TEXT,
    fitness_context JSONB NOT NULL DEFAULT '{}'::jsonb,
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 5. HEALTH METRICS & BIOMETRICS DOMAIN TABLES
-- ============================================================================

-- Health Metrics Table (Daily Recovery, HRV, Sleep, Steps)
CREATE TABLE IF NOT EXISTS public.health_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    sleep_hours NUMERIC(4, 2),
    heart_rate INTEGER,
    hrv NUMERIC(6, 2),
    steps INTEGER NOT NULL DEFAULT 0,
    recovery_score NUMERIC(5, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_health_metrics_user_date UNIQUE (user_id, date)
);

-- ============================================================================
-- 6. COMMUNITY & SOCIAL DOMAIN TABLES
-- ============================================================================

-- Community Posts Table
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caption TEXT,
    media_url TEXT,
    likes_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Post Comments Table
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 7. PERFORMANCE INDEXING
-- ============================================================================

-- Workout Sessions Indexes
CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_created ON public.workout_sessions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_started ON public.workout_sessions(started_at DESC);

-- Workout Exercises Indexes
CREATE INDEX IF NOT EXISTS idx_workout_exercises_session ON public.workout_exercises(session_id);

-- Nutrition Logs Indexes
CREATE INDEX IF NOT EXISTS idx_nutrition_logs_user_date ON public.nutrition_logs(user_id, date DESC);

-- Meal Entries Indexes
CREATE INDEX IF NOT EXISTS idx_meal_entries_log_id ON public.meal_entries(nutrition_log_id);

-- AI Memory Indexes
CREATE INDEX IF NOT EXISTS idx_ai_memory_user ON public.ai_memory(user_id, created_at DESC);

-- Health Metrics Indexes
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_date ON public.health_metrics(user_id, date DESC);

-- Community Posts & Comments Indexes
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON public.posts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post_created ON public.comments(post_id, created_at ASC);

-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fitness_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- 8.1 Profiles RLS Policies
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

-- 8.2 Fitness Profiles RLS Policies
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

-- 8.3 Workout Sessions RLS Policies
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

-- 8.4 Workout Exercises RLS Policies (Derived via parent workout_sessions)
DROP POLICY IF EXISTS "workout_exercises_select_own" ON public.workout_exercises;
CREATE POLICY "workout_exercises_select_own" ON public.workout_exercises
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "workout_exercises_insert_own" ON public.workout_exercises;
CREATE POLICY "workout_exercises_insert_own" ON public.workout_exercises
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "workout_exercises_update_own" ON public.workout_exercises;
CREATE POLICY "workout_exercises_update_own" ON public.workout_exercises
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "workout_exercises_delete_own" ON public.workout_exercises;
CREATE POLICY "workout_exercises_delete_own" ON public.workout_exercises
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    );

-- 8.5 Nutrition Logs RLS Policies
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

-- 8.6 Meal Entries RLS Policies (Derived via parent nutrition_logs)
DROP POLICY IF EXISTS "meal_entries_select_own" ON public.meal_entries;
CREATE POLICY "meal_entries_select_own" ON public.meal_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "meal_entries_insert_own" ON public.meal_entries;
CREATE POLICY "meal_entries_insert_own" ON public.meal_entries
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "meal_entries_update_own" ON public.meal_entries;
CREATE POLICY "meal_entries_update_own" ON public.meal_entries
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "meal_entries_delete_own" ON public.meal_entries;
CREATE POLICY "meal_entries_delete_own" ON public.meal_entries
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    );

-- 8.7 AI Memory RLS Policies
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

-- 8.8 Health Metrics RLS Policies
DROP POLICY IF EXISTS "health_metrics_select_own" ON public.health_metrics;
CREATE POLICY "health_metrics_select_own" ON public.health_metrics
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "health_metrics_insert_own" ON public.health_metrics;
CREATE POLICY "health_metrics_insert_own" ON public.health_metrics
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "health_metrics_update_own" ON public.health_metrics;
CREATE POLICY "health_metrics_update_own" ON public.health_metrics
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "health_metrics_delete_own" ON public.health_metrics;
CREATE POLICY "health_metrics_delete_own" ON public.health_metrics
    FOR DELETE USING (auth.uid() = user_id);

-- 8.9 Community Posts RLS Policies (Public view, owner mutation)
DROP POLICY IF EXISTS "posts_select_all" ON public.posts;
CREATE POLICY "posts_select_all" ON public.posts
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "posts_insert_own" ON public.posts;
CREATE POLICY "posts_insert_own" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "posts_update_own" ON public.posts;
CREATE POLICY "posts_update_own" ON public.posts
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "posts_delete_own" ON public.posts;
CREATE POLICY "posts_delete_own" ON public.posts
    FOR DELETE USING (auth.uid() = user_id);

-- 8.10 Comments RLS Policies (Public view, owner mutation)
DROP POLICY IF EXISTS "comments_select_all" ON public.comments;
CREATE POLICY "comments_select_all" ON public.comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "comments_insert_own" ON public.comments;
CREATE POLICY "comments_insert_own" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "comments_update_own" ON public.comments;
CREATE POLICY "comments_update_own" ON public.comments
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "comments_delete_own" ON public.comments;
CREATE POLICY "comments_delete_own" ON public.comments
    FOR DELETE USING (auth.uid() = user_id);
