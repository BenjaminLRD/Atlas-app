-- FitForge AI Personalization & Predictive Intelligence Engine Database Schema
-- Tables: user_behavior_events, model_predictions, personalization_profiles

-- 1. USER BEHAVIOR EVENTS (Telemetry & Habit Tracking)
CREATE TABLE IF NOT EXISTS public.user_behavior_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    domain TEXT NOT NULL, -- 'workout', 'nutrition', 'ai_coach', 'community'
    event_type TEXT NOT NULL, -- 'workout_completed', 'workout_skipped', 'meal_logged', 'coach_question', 'recommendation_accepted'
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_behavior_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own behavior events"
ON public.user_behavior_events FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own behavior events"
ON public.user_behavior_events FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 2. MODEL PREDICTIONS (Inference Outputs & Churn Scores)
CREATE TABLE IF NOT EXISTS public.model_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    model_name TEXT NOT NULL, -- 'workout_recommendation', 'churn_prediction', 'recovery_prediction'
    prediction_output JSONB NOT NULL,
    confidence_score DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.model_predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own model predictions"
ON public.model_predictions FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert model predictions"
ON public.model_predictions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. PERSONALIZATION PROFILES (Feature Vectors & Discovered Habits)
CREATE TABLE IF NOT EXISTS public.personalization_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    feature_vector JSONB NOT NULL DEFAULT '{}'::jsonb,
    preferred_training_time TEXT DEFAULT 'evening',
    churn_risk TEXT DEFAULT 'low',
    discovered_insights JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.personalization_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own personalization profile"
ON public.personalization_profiles FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own personalization profile"
ON public.personalization_profiles FOR ALL USING (auth.uid() = user_id);
