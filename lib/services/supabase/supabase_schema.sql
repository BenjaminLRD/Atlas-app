-- ============================================================================
-- Supabase Cloud Production Schema & Row Level Security (RLS) Configuration
-- Atlas / Atlas Flutter Application (Phase B.4)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. USER DOMAIN (Profiles, User Preferences, User Goals)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL,
    avatar_url TEXT,
    phone TEXT,
    dob DATE,
    gender TEXT DEFAULT 'Male',
    height_cm NUMERIC(5,2) DEFAULT 175.0,
    weight_kg NUMERIC(5,2) DEFAULT 70.0,
    fitness_goal TEXT DEFAULT 'Muscle Gain',
    workout_experience TEXT DEFAULT 'Intermediate',
    diet_preference TEXT DEFAULT 'High Protein',
    subscription_tier TEXT DEFAULT 'Free',
    mass_unit TEXT DEFAULT 'kg',
    length_unit TEXT DEFAULT 'cm',
    privacy_setting TEXT DEFAULT 'Public',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    training_style TEXT DEFAULT 'Hypertrophy',
    preferred_duration INT DEFAULT 45,
    equipment TEXT[] DEFAULT '{}',
    exercise_preferences JSONB DEFAULT '{}'::jsonb,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    theme_mode TEXT DEFAULT 'dark',
    mass_unit TEXT DEFAULT 'kg',
    length_unit TEXT DEFAULT 'cm',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_preferences UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.user_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL DEFAULT 'muscleGain',
    fitness_level TEXT NOT NULL DEFAULT 'intermediate',
    activity_level TEXT NOT NULL DEFAULT 'moderate',
    current_weight NUMERIC(5,2) NOT NULL DEFAULT 70.0,
    target_weight NUMERIC(5,2) NOT NULL DEFAULT 75.0,
    timeline TEXT DEFAULT '12 weeks',
    target_calories INT NOT NULL DEFAULT 2500,
    target_protein NUMERIC(6,2) NOT NULL DEFAULT 150.0,
    target_carbohydrates NUMERIC(6,2) NOT NULL DEFAULT 280.0,
    target_fats NUMERIC(6,2) NOT NULL DEFAULT 70.0,
    weekly_workout_days INT NOT NULL DEFAULT 4,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_goals UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.weight_goals (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL,
    start_weight_kg NUMERIC NOT NULL,
    current_weight_kg NUMERIC NOT NULL,
    target_weight_kg NUMERIC NOT NULL,
    weekly_pace_kg NUMERIC NOT NULL,
    daily_calories INT NOT NULL,
    protein_g NUMERIC NOT NULL,
    carbs_g NUMERIC NOT NULL,
    fats_g NUMERIC NOT NULL,
    diet_preference TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ============================================================================
-- 2. WORKOUT DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.workouts (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'strength',
    difficulty TEXT NOT NULL DEFAULT 'intermediate',
    duration_minutes INT NOT NULL DEFAULT 45,
    target_muscle_group TEXT,
    exercises_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.workout_sessions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    workout_id TEXT,
    workout_name TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    completed_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    duration INT NOT NULL DEFAULT 0,
    duration_seconds INT NOT NULL DEFAULT 0,
    total_volume NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    total_volume_kg NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    calories_burned NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    exercises_completed INT NOT NULL DEFAULT 0,
    completion_percentage NUMERIC(5,2) NOT NULL DEFAULT 100.0,
    notes TEXT,
    personal_records JSONB DEFAULT '[]'::jsonb,
    xp_earned INT NOT NULL DEFAULT 0,
    exercises_data JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
    exercise_id TEXT,
    exercise_name TEXT NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    sets_completed INT NOT NULL DEFAULT 0,
    total_reps INT NOT NULL DEFAULT 0,
    max_weight NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    target_muscle_group TEXT,
    sets_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    set_number INT NOT NULL,
    weight NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    reps INT NOT NULL DEFAULT 0,
    rpe NUMERIC(3,1) DEFAULT 8.0,
    completed BOOLEAN NOT NULL DEFAULT TRUE,
    is_pr BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.personal_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    record_type TEXT NOT NULL DEFAULT 'weight',
    value NUMERIC(10,2) NOT NULL,
    reps INT NOT NULL DEFAULT 1,
    one_rep_max_kg NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    achieved_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ============================================================================
-- 3. NUTRITION DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.foods (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    calories INT NOT NULL DEFAULT 0,
    protein NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    carbs NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    fat NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    source TEXT NOT NULL DEFAULT 'system',
    serving_size TEXT NOT NULL DEFAULT '100g',
    barcode TEXT,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.nutrition_logs (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    log_date DATE NOT NULL,
    total_calories INT NOT NULL DEFAULT 0,
    total_protein NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    total_carbs NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    total_fats NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    water_liters NUMERIC(4,2) NOT NULL DEFAULT 0.0,
    meals JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_nutrition_date UNIQUE (user_id, date)
);

CREATE TABLE IF NOT EXISTS public.meal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nutrition_log_id TEXT NOT NULL REFERENCES public.nutrition_logs(id) ON DELETE CASCADE,
    food_id TEXT REFERENCES public.foods(id) ON DELETE SET NULL,
    food_name TEXT NOT NULL,
    meal_category TEXT NOT NULL DEFAULT 'breakfast',
    quantity NUMERIC(6,2) NOT NULL DEFAULT 1.0,
    serving_size TEXT NOT NULL DEFAULT '1 serving',
    calories INT NOT NULL DEFAULT 0,
    protein NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    carbs NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    fat NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    logged_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ============================================================================
-- 4. AI DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    memory_type TEXT NOT NULL,
    memory_value JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL DEFAULT 'default_coach_session',
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    context_snapshot JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ai_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    recommendation TEXT NOT NULL,
    feedback TEXT NOT NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ============================================================================
-- 5. HEALTH & RECOVERY DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.health_metrics (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    metric_date DATE NOT NULL,
    heart_rate INT,
    resting_heart_rate INT,
    sleep_hours NUMERIC(4,2),
    sleep_minutes INT,
    deep_sleep_minutes INT,
    steps INT NOT NULL DEFAULT 0,
    distance_km NUMERIC(6,2) NOT NULL DEFAULT 0.0,
    active_calories NUMERIC(8,2) NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_health_date UNIQUE (user_id, date)
);

CREATE TABLE IF NOT EXISTS public.recovery_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    score_date DATE NOT NULL,
    score INT NOT NULL CHECK (score >= 0 AND score <= 100),
    recovery_score INT NOT NULL CHECK (recovery_score >= 0 AND recovery_score <= 100),
    factors JSONB NOT NULL DEFAULT '{}'::jsonb,
    sleep_pillar NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    training_pillar NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    movement_pillar NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    rest_pillar NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    readiness_state TEXT NOT NULL DEFAULT 'optimal',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_recovery_date UNIQUE (user_id, date)
);


-- ============================================================================
-- 6. SOCIAL DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.community_posts (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    author_rank TEXT DEFAULT 'Athlete',
    content TEXT NOT NULL,
    caption TEXT NOT NULL,
    post_type TEXT NOT NULL DEFAULT 'general',
    media_url TEXT,
    metrics_payload JSONB DEFAULT '{}'::jsonb,
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.comments (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    post_id TEXT NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.post_reactions (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    post_id TEXT NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'like',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_post_user_reaction UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.challenges (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'training',
    target_value NUMERIC(10,2) NOT NULL DEFAULT 1.0,
    reward_xp INT NOT NULL DEFAULT 100,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.challenge_participants (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    challenge_id TEXT NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    current_progress NUMERIC(10,2) NOT NULL DEFAULT 0.0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    reward_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_challenge_participant UNIQUE (challenge_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.leaderboards (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    total_xp INT NOT NULL DEFAULT 0,
    rank_title TEXT NOT NULL DEFAULT 'Bronze I',
    division TEXT NOT NULL DEFAULT 'Division III',
    country TEXT NOT NULL DEFAULT 'India',
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT unique_user_leaderboard UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.friendships (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ,
    CONSTRAINT unique_friendship_pair UNIQUE (requester_id, receiver_id),
    CONSTRAINT check_not_self_friendship CHECK (requester_id != receiver_id)
);


-- ============================================================================
-- 7. ANALYTICS & PREDICTIVE INTELLIGENCE DOMAIN
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    properties JSONB NOT NULL DEFAULT '{}'::jsonb,
    session_id TEXT,
    client_timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_behavior_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    domain TEXT NOT NULL, -- 'workout', 'nutrition', 'aiCoach', 'community'
    event_type TEXT NOT NULL, -- 'workout_completed', 'workout_skipped', 'meal_logged', 'coach_interaction', 'question_asked', 'challenge_joined'
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.model_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    model_name TEXT NOT NULL, -- 'workout_recommendation_model', 'churn_prediction_model', 'recovery_prediction_model'
    prediction_output JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence_score DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.personalization_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    feature_vector JSONB NOT NULL DEFAULT '{}'::jsonb,
    preferred_training_time TEXT DEFAULT 'evening',
    churn_risk TEXT DEFAULT 'low',
    discovered_insights JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ml_training_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL, -- Cryptographically anonymized user identifier
    domain TEXT NOT NULL, -- 'workout', 'nutrition', 'recovery', 'behavior'
    event_type TEXT NOT NULL,
    feature_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_anonymized BOOLEAN DEFAULT true,
    consent_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.digital_athlete_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    physical_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    strength_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    training_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    recovery_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    nutrition_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    behavior_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    goal_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    biomechanics_weaknesses JSONB NOT NULL DEFAULT '[]'::jsonb,
    form_score_averages JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.athlete_insights (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL, -- 'strength', 'recovery', 'consistency', 'biomechanics', 'nutrition'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    recommendation TEXT NOT NULL,
    significance_score DOUBLE PRECISION DEFAULT 0.85,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.prediction_results (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    prediction_type TEXT NOT NULL, -- 'strength_timeline', 'goal_achievement', 'biomechanics_trend'
    prediction_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence_score DOUBLE PRECISION DEFAULT 0.90,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.beta_feedbacks (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    feedback TEXT NOT NULL,
    category TEXT NOT NULL, -- 'bug', 'feature_request', 'ui_issue', 'ai_issue'
    priority TEXT DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    device_info JSONB DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);


-- ============================================================================
-- 8. INDEXES & PERFORMANCE OPTIMIZATIONS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_date ON public.workout_sessions(user_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_workout_id ON public.workout_sessions(workout_id);
CREATE INDEX IF NOT EXISTS idx_workout_exercises_session ON public.workout_exercises(session_id);
CREATE INDEX IF NOT EXISTS idx_workout_sets_session ON public.workout_sets(session_id);
CREATE INDEX IF NOT EXISTS idx_workout_sets_exercise ON public.workout_sets(exercise_id);
CREATE INDEX IF NOT EXISTS idx_personal_records_user_exercise ON public.personal_records(user_id, exercise_id);

CREATE INDEX IF NOT EXISTS idx_nutrition_logs_user_date ON public.nutrition_logs(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_logs_user_logdate ON public.nutrition_logs(user_id, log_date DESC);
CREATE INDEX IF NOT EXISTS idx_meal_entries_log ON public.meal_entries(nutrition_log_id);
CREATE INDEX IF NOT EXISTS idx_meal_entries_food ON public.meal_entries(food_id);
CREATE INDEX IF NOT EXISTS idx_foods_name ON public.foods(name);
CREATE INDEX IF NOT EXISTS idx_foods_category ON public.foods(category);

CREATE INDEX IF NOT EXISTS idx_ai_memory_user_type ON public.ai_memory(user_id, memory_type);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_session ON public.ai_conversations(user_id, session_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_user ON public.ai_feedback(user_id);

CREATE INDEX IF NOT EXISTS idx_health_metrics_user_date ON public.health_metrics(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_recovery_scores_user_date ON public.recovery_scores(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_created ON public.community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_user ON public.community_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_created ON public.comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_post_reactions_post ON public.post_reactions(post_id);
CREATE INDEX IF NOT EXISTS idx_leaderboards_total_xp ON public.leaderboards(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_receiver ON public.friendships(receiver_id);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_time ON public.analytics_events(event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON public.analytics_events(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_behavior_events_user_time ON public.user_behavior_events(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_user_behavior_events_domain ON public.user_behavior_events(domain);
CREATE INDEX IF NOT EXISTS idx_model_predictions_user ON public.model_predictions(user_id, created_at DESC);


-- ============================================================================
-- 9. ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recovery_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_behavior_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.model_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ml_training_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_athlete_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athlete_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prediction_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.beta_feedbacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles can be viewed by all authenticated users"
    ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
    ON public.profiles FOR DELETE USING (auth.uid() = id);

CREATE POLICY "Users can manage own preferences"
    ON public.user_preferences FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own goals"
    ON public.user_goals FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Workouts catalog is readable by all authenticated users"
    ON public.workouts FOR SELECT TO authenticated USING (is_custom = FALSE OR creator_id = auth.uid());

CREATE POLICY "Users can manage own custom workouts"
    ON public.workouts FOR ALL USING (auth.uid() = creator_id) WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can manage own workout sessions"
    ON public.workout_sessions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can access own workout exercises"
    ON public.workout_exercises FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_exercises.session_id AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access own workout sets"
    ON public.workout_sets FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s
            WHERE s.id = workout_sets.session_id AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can manage own personal records"
    ON public.personal_records FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Foods catalog is readable by all authenticated users"
    ON public.foods FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert custom foods"
    ON public.foods FOR INSERT TO authenticated WITH CHECK (auth.uid() = creator_id OR creator_id IS NULL);

CREATE POLICY "Users can manage own nutrition logs"
    ON public.nutrition_logs FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can access own meal entries"
    ON public.meal_entries FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.nutrition_logs n
            WHERE n.id = meal_entries.nutrition_log_id AND n.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can access own AI memory"
    ON public.ai_memory FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can access own AI conversations"
    ON public.ai_conversations FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can access own AI feedback"
    ON public.ai_feedback FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own health metrics"
    ON public.health_metrics FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own recovery scores"
    ON public.recovery_scores FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Community posts are viewable by all authenticated users"
    ON public.community_posts FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage own community posts"
    ON public.community_posts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Comments are viewable by all authenticated users"
    ON public.comments FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage own comments"
    ON public.comments FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Post reactions are viewable by all authenticated users"
    ON public.post_reactions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage own post reactions"
    ON public.post_reactions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Challenges are viewable by all authenticated users"
    ON public.challenges FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage own challenge participation"
    ON public.challenge_participants FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Leaderboards are viewable by all authenticated users"
    ON public.leaderboards FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage own leaderboard entry"
    ON public.leaderboards FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view friendships involving them"
    ON public.friendships FOR SELECT TO authenticated USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can manage friendships involving them"
    ON public.friendships FOR ALL TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = receiver_id)
    WITH CHECK (auth.uid() = requester_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can insert analytics events"
    ON public.analytics_events FOR INSERT TO authenticated WITH CHECK (user_id IS NULL OR auth.uid() = user_id);

CREATE POLICY "Users can view own analytics events"
    ON public.analytics_events FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own behavior events"
    ON public.user_behavior_events FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own model predictions"
    ON public.model_predictions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own personalization profile"
    ON public.personalization_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage training events"
    ON public.ml_training_events FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Users can manage own digital athlete profile"
    ON public.digital_athlete_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own athlete insights"
    ON public.athlete_insights FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own prediction results"
    ON public.prediction_results FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own beta feedback"
    ON public.beta_feedbacks FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);


-- ============================================================================
-- 10. DATABASE FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_weekly_volume(
    p_user_id UUID,
    p_start_date TIMESTAMPTZ DEFAULT (NOW() - INTERVAL '7 days')
)
RETURNS NUMERIC AS $$
DECLARE
    v_total_volume NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total_volume), 0.0)
    INTO v_total_volume
    FROM public.workout_sessions
    WHERE user_id = p_user_id
      AND completed_at >= p_start_date;
      
    RETURN v_total_volume;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.calculate_training_streak(
    p_user_id UUID
)
RETURNS INT AS $$
DECLARE
    v_streak INT := 0;
    v_curr_date DATE := CURRENT_DATE;
    v_has_workout BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.workout_sessions
        WHERE user_id = p_user_id AND DATE(completed_at) = v_curr_date
    ) INTO v_has_workout;

    IF NOT v_has_workout THEN
        v_curr_date := v_curr_date - 1;
    END IF;

    LOOP
        SELECT EXISTS (
            SELECT 1 FROM public.workout_sessions
            WHERE user_id = p_user_id AND DATE(completed_at) = v_curr_date
        ) INTO v_has_workout;

        IF v_has_workout THEN
            v_streak := v_streak + 1;
            v_curr_date := v_curr_date - 1;
        ELSE
            EXIT;
        END IF;
    END LOOP;

    RETURN v_streak;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.calculate_leaderboard_rank(
    p_user_id UUID
)
RETURNS INT AS $$
DECLARE
    v_rank INT;
    v_user_xp INT;
BEGIN
    SELECT total_xp INTO v_user_xp
    FROM public.leaderboards
    WHERE user_id = p_user_id;

    IF v_user_xp IS NULL THEN
        RETURN 0;
    END IF;

    SELECT COUNT(*) + 1
    INTO v_rank
    FROM public.leaderboards
    WHERE total_xp > v_user_xp;

    RETURN v_rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.record_ai_memory(
    p_user_id UUID,
    p_memory_type TEXT,
    p_memory_value JSONB,
    p_confidence NUMERIC DEFAULT 1.0
)
RETURNS UUID AS $$
DECLARE
    v_memory_id UUID;
BEGIN
    INSERT INTO public.ai_memory (user_id, memory_type, memory_value, confidence, updated_at)
    VALUES (p_user_id, p_memory_type, p_memory_value, p_confidence, NOW())
    RETURNING id INTO v_memory_id;
    
    RETURN v_memory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_user_readiness_summary(
    p_user_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT json_build_object(
        'date', p_date,
        'recovery_score', r.score,
        'readiness_state', r.readiness_state,
        'resting_heart_rate', h.resting_heart_rate,
        'sleep_hours', h.sleep_hours,
        'steps', h.steps
    )::jsonb INTO v_result
    FROM public.recovery_scores r
    LEFT JOIN public.health_metrics h ON h.user_id = r.user_id AND h.date = r.date
    WHERE r.user_id = p_user_id AND r.date = p_date;

    RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
