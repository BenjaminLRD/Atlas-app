-- FitForge Digital Athlete Intelligence & Advanced AI Learning Database Schema
-- Tables: digital_athlete_profiles, athlete_insights, prediction_results

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

CREATE INDEX IF NOT EXISTS idx_athlete_insights_user ON public.athlete_insights(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prediction_results_user ON public.prediction_results(user_id, created_at DESC);

ALTER TABLE public.digital_athlete_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athlete_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prediction_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own digital athlete profile"
    ON public.digital_athlete_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own athlete insights"
    ON public.athlete_insights FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage own prediction results"
    ON public.prediction_results FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
