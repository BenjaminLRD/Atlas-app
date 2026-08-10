-- Supabase Cloud Schema & Security Configuration for Aizawl Gym
-- Enable Row Level Security (RLS) policies on all tables so users can only access their own records.

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    age INT NOT NULL DEFAULT 25,
    height_cm NUMERIC NOT NULL DEFAULT 175.0,
    weight_kg NUMERIC NOT NULL DEFAULT 70.0,
    fitness_level TEXT NOT NULL DEFAULT 'Beginner',
    profile_pic TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" 
    ON public.profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);


-- 2. User Goals Table
CREATE TABLE IF NOT EXISTS public.user_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL DEFAULT 'muscleGain',
    target_weight NUMERIC NOT NULL DEFAULT 75.0,
    weekly_workout_days INT NOT NULL DEFAULT 4,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on user_id for user_goals
CREATE INDEX IF NOT EXISTS idx_user_goals_user_id ON public.user_goals(user_id);

-- Enable RLS for User Goals
ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own goals" 
    ON public.user_goals FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals" 
    ON public.user_goals FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals" 
    ON public.user_goals FOR UPDATE 
    USING (auth.uid() = user_id);


-- 3. Workout Sessions Table
CREATE TABLE IF NOT EXISTS public.workout_sessions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id TEXT NOT NULL,
    workout_name TEXT NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_minutes INT NOT NULL DEFAULT 0,
    total_volume_kg NUMERIC NOT NULL DEFAULT 0.0,
    calories_burned INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on user_id and completed_at for workout_sessions
CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_id ON public.workout_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_completed_at ON public.workout_sessions(completed_at DESC);

-- Enable RLS for Workout Sessions
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own workout sessions" 
    ON public.workout_sessions FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workout sessions" 
    ON public.workout_sessions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workout sessions" 
    ON public.workout_sessions FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workout sessions" 
    ON public.workout_sessions FOR DELETE 
    USING (auth.uid() = user_id);


-- 4. Workout Exercises Table
CREATE TABLE IF NOT EXISTS public.workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    sets_completed INT NOT NULL DEFAULT 0,
    weight_used NUMERIC NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on session_id for workout_exercises
CREATE INDEX IF NOT EXISTS idx_workout_exercises_session_id ON public.workout_exercises(session_id);

-- Enable RLS for Workout Exercises
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can access own workout exercises" 
    ON public.workout_exercises FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions s 
            WHERE s.id = workout_exercises.session_id 
              AND s.user_id = auth.uid()
        )
    );


-- 5. Leaderboard Entries Table
CREATE TABLE IF NOT EXISTS public.leaderboard_entries (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    total_xp INT NOT NULL DEFAULT 0,
    rank_title TEXT NOT NULL DEFAULT 'Bronze I',
    division TEXT NOT NULL DEFAULT 'Division III',
    country TEXT NOT NULL DEFAULT 'India',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes on total_xp DESC and country
CREATE INDEX IF NOT EXISTS idx_leaderboard_total_xp ON public.leaderboard_entries(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_country ON public.leaderboard_entries(country);

-- Enable RLS for Leaderboard Entries
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read leaderboard entries" 
    ON public.leaderboard_entries FOR SELECT 
    USING (true);

CREATE POLICY "Users can insert own leaderboard entry" 
    ON public.leaderboard_entries FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own leaderboard entry" 
    ON public.leaderboard_entries FOR UPDATE 
    USING (auth.uid() = user_id);


-- 6. Challenges Table
CREATE TABLE IF NOT EXISTS public.challenges (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'training',
    target_value NUMERIC NOT NULL DEFAULT 1.0,
    reward_xp INT NOT NULL DEFAULT 100,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for active dates and category
CREATE INDEX IF NOT EXISTS idx_challenges_category ON public.challenges(category);
CREATE INDEX IF NOT EXISTS idx_challenges_dates ON public.challenges(start_date, end_date);

-- Enable RLS for Challenges
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read challenges"
    ON public.challenges FOR SELECT
    USING (true);


-- 7. User Challenges Table
CREATE TABLE IF NOT EXISTS public.user_challenges (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_id TEXT NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    current_progress NUMERIC NOT NULL DEFAULT 0.0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    reward_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT user_challenge_unique UNIQUE (user_id, challenge_id)
);

-- Indexes for user challenges lookups
CREATE INDEX IF NOT EXISTS idx_user_challenges_user ON public.user_challenges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_challenges_challenge ON public.user_challenges(challenge_id);

-- Enable RLS for User Challenges
ALTER TABLE public.user_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own user challenges"
    ON public.user_challenges FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own user challenges"
    ON public.user_challenges FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own user challenges"
    ON public.user_challenges FOR UPDATE
    USING (auth.uid() = user_id);


-- 8. Friendships Table
CREATE TABLE IF NOT EXISTS public.friendships (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'declined'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT friendship_user_pair_unique UNIQUE (requester_id, receiver_id)
);

-- Indexes for friendship queries
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_receiver ON public.friendships(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

-- Enable RLS for Friendships
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view friendships involving them"
    ON public.friendships FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can insert friend requests"
    ON public.friendships FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update friendships involving them"
    ON public.friendships FOR UPDATE
    USING (auth.uid() = requester_id OR auth.uid() = receiver_id);


-- 9. Activity Feed Table
CREATE TABLE IF NOT EXISTS public.activity_feed (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'workout', 'achievement', 'rank_up', 'challenge'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB
);

-- Indexes for activity feed queries
CREATE INDEX IF NOT EXISTS idx_activity_user ON public.activity_feed(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_created_at ON public.activity_feed(created_at DESC);

-- Enable RLS for Activity Feed
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read activity feed"
    ON public.activity_feed FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own activity items"
    ON public.activity_feed FOR INSERT
    WITH CHECK (auth.uid() = user_id);


-- 10. Seasons Table
CREATE TABLE IF NOT EXISTS public.seasons (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    reward_description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for season queries
CREATE INDEX IF NOT EXISTS idx_seasons_dates ON public.seasons(start_date, end_date);

-- Enable RLS for Seasons
ALTER TABLE public.seasons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read seasons"
    ON public.seasons FOR SELECT
    USING (true);


-- 11. Season Progress Table
CREATE TABLE IF NOT EXISTS public.season_progress (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    season_id TEXT NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    season_xp INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT season_user_unique UNIQUE (season_id, user_id)
);

-- Indexes for season progress lookups & leaderboards
CREATE INDEX IF NOT EXISTS idx_season_progress_season ON public.season_progress(season_id);
CREATE INDEX IF NOT EXISTS idx_season_progress_user ON public.season_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_season_progress_xp ON public.season_progress(season_id, season_xp DESC);

-- Enable RLS for Season Progress
ALTER TABLE public.season_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read season progress"
    ON public.season_progress FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own season progress"
    ON public.season_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own season progress"
    ON public.season_progress FOR UPDATE
    USING (auth.uid() = user_id);




