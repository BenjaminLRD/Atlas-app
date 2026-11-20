-- FitForge Social Fitness Ecosystem 2.0 Database Schema
-- Tables: social_profiles, posts, comments, likes, followers, challenges, challenge_participants

-- 1. SOCIAL PROFILES
CREATE TABLE IF NOT EXISTS public.social_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    fitness_level TEXT DEFAULT 'Intermediate',
    total_xp BIGINT DEFAULT 0,
    rank_title TEXT DEFAULT 'Beginner',
    followers_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    workouts_completed INT DEFAULT 0,
    total_volume_kg DOUBLE PRECISION DEFAULT 0.0,
    current_streak_days INT DEFAULT 0,
    achievements JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.social_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public social profiles are viewable by everyone" 
ON public.social_profiles FOR SELECT USING (true);

CREATE POLICY "Users can update their own social profile" 
ON public.social_profiles FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own social profile" 
ON public.social_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 2. POSTS (Community Feed & Transformations)
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'workout', 'achievement', 'transformation', 'milestone'
    content TEXT,
    media_url TEXT,
    transformation_data JSONB, -- { beforeImage, afterImage, durationWeeks, weightChangeKg, strengthChanges }
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Posts are viewable by authenticated users" 
ON public.posts FOR SELECT USING (true);

CREATE POLICY "Users can insert their own posts" 
ON public.posts FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts" 
ON public.posts FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts" 
ON public.posts FOR DELETE USING (auth.uid() = author_id);

-- 3. COMMENTS
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Comments are viewable by everyone" 
ON public.comments FOR SELECT USING (true);

CREATE POLICY "Users can insert their own comments" 
ON public.comments FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can delete their own comments" 
ON public.comments FOR DELETE USING (auth.uid() = author_id);

-- 4. LIKES
CREATE TABLE IF NOT EXISTS public.likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Likes are viewable by everyone" 
ON public.likes FOR SELECT USING (true);

CREATE POLICY "Users can toggle their own likes" 
ON public.likes FOR ALL USING (auth.uid() = user_id);

-- 5. FOLLOWERS (Social Graph)
CREATE TABLE IF NOT EXISTS public.followers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(follower_id, following_id)
);

ALTER TABLE public.followers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Follows are viewable by everyone" 
ON public.followers FOR SELECT USING (true);

CREATE POLICY "Users can manage their follows" 
ON public.followers FOR ALL USING (auth.uid() = follower_id);

-- 6. CHALLENGES
CREATE TABLE IF NOT EXISTS public.challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL, -- 'workoutCount', 'volumeTarget', 'strengthMilestone', 'weightGoal', 'consistencyStreak'
    goal_value DOUBLE PRECISION NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    xp_reward INT DEFAULT 500,
    badge_reward TEXT,
    participants_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Challenges viewable by all users" 
ON public.challenges FOR SELECT USING (true);

-- 7. CHALLENGE PARTICIPANTS
CREATE TABLE IF NOT EXISTS public.challenge_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    progress_value DOUBLE PRECISION DEFAULT 0.0,
    is_completed BOOLEAN DEFAULT false,
    reward_claimed BOOLEAN DEFAULT false,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(challenge_id, user_id)
);

ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Challenge participants viewable by all" 
ON public.challenge_participants FOR SELECT USING (true);

CREATE POLICY "Users can manage their challenge participation" 
ON public.challenge_participants FOR ALL USING (auth.uid() = user_id);
