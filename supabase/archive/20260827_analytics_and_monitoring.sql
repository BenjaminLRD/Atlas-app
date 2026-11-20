-- FitForge Startup Launch Preparation: Product Analytics & Beta Infrastructure Schema
-- Tables: analytics_events, beta_feedbacks

CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_name TEXT NOT NULL,
    event_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
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

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_time ON public.analytics_events(event_name, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON public.analytics_events(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_beta_feedbacks_user ON public.beta_feedbacks(user_id, timestamp DESC);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.beta_feedbacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own analytics events"
    ON public.analytics_events FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own analytics events"
    ON public.analytics_events FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own beta feedback"
    ON public.beta_feedbacks FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own beta feedback"
    ON public.beta_feedbacks FOR SELECT USING (auth.uid() = user_id);
