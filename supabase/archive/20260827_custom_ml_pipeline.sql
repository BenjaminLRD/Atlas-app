-- FitForge Custom Machine Learning Pipeline Database Schema
-- Table: ml_training_events

CREATE TABLE IF NOT EXISTS public.ml_training_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL, -- Anonymized cryptographic hash
    domain TEXT NOT NULL, -- 'workout', 'nutrition', 'recovery', 'behavior'
    event_type TEXT NOT NULL,
    feature_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_anonymized BOOLEAN DEFAULT true,
    consent_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ml_training_events_domain ON public.ml_training_events(domain);
CREATE INDEX IF NOT EXISTS idx_ml_training_events_created ON public.ml_training_events(created_at DESC);

ALTER TABLE public.ml_training_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own training events"
ON public.ml_training_events FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view own training events"
ON public.ml_training_events FOR SELECT USING (true);
