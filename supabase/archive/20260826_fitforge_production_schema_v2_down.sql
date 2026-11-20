-- ============================================================================
-- FitForge Production Database Architecture Reversible Rollback Script
-- Version: 20260826_fitforge_production_schema_v2_down
-- Description: Reversible teardown for Phase B.4 schema migration.
-- ============================================================================

-- Drop Functions
DROP FUNCTION IF EXISTS public.get_user_readiness_summary(UUID, DATE);
DROP FUNCTION IF EXISTS public.record_ai_memory(UUID, TEXT, JSONB, NUMERIC);
DROP FUNCTION IF EXISTS public.calculate_leaderboard_rank(UUID);
DROP FUNCTION IF EXISTS public.calculate_training_streak(UUID);
DROP FUNCTION IF EXISTS public.calculate_weekly_volume(UUID, TIMESTAMPTZ);

-- Drop Analytics Domain
DROP TABLE IF EXISTS public.analytics_events CASCADE;

-- Drop Social Domain
DROP TABLE IF EXISTS public.friendships CASCADE;
DROP TABLE IF EXISTS public.leaderboards CASCADE;
DROP TABLE IF EXISTS public.challenge_participants CASCADE;
DROP TABLE IF EXISTS public.challenges CASCADE;
DROP TABLE IF EXISTS public.post_reactions CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.community_posts CASCADE;

-- Drop Health Domain
DROP TABLE IF EXISTS public.recovery_scores CASCADE;
DROP TABLE IF EXISTS public.health_metrics CASCADE;

-- Drop AI Domain
DROP TABLE IF EXISTS public.ai_feedback CASCADE;
DROP TABLE IF EXISTS public.ai_conversations CASCADE;
DROP TABLE IF EXISTS public.ai_memory CASCADE;

-- Drop Nutrition Domain
DROP TABLE IF EXISTS public.meal_entries CASCADE;
DROP TABLE IF EXISTS public.nutrition_logs CASCADE;
DROP TABLE IF EXISTS public.foods CASCADE;

-- Drop Workout Domain
DROP TABLE IF EXISTS public.personal_records CASCADE;
DROP TABLE IF EXISTS public.workout_sets CASCADE;
DROP TABLE IF EXISTS public.workout_exercises CASCADE;
DROP TABLE IF EXISTS public.workout_sessions CASCADE;
DROP TABLE IF EXISTS public.workouts CASCADE;

-- Drop User Domain
DROP TABLE IF EXISTS public.user_goals CASCADE;
DROP TABLE IF EXISTS public.user_preferences CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
