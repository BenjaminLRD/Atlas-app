-- ==============================================================================
-- ATLAS PRODUCTION SCALABILITY INDEXES & PARTITIONING (1M+ ATHLETES)
-- ==============================================================================

-- 1. Workout History Composite Indexes
CREATE INDEX IF NOT EXISTS idx_workouts_user_date 
ON public.workout_history (user_id, date_completed DESC);

CREATE INDEX IF NOT EXISTS idx_workouts_completion_volume 
ON public.workout_history (user_id, completion_percentage, total_volume DESC);

-- 2. AI Memory Composite Indexes
CREATE INDEX IF NOT EXISTS idx_fitness_memory_user_importance 
ON public.fitness_memories (user_id, importance_score DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fitness_memory_category 
ON public.fitness_memories (user_id, category);

-- 3. Nutrition Logs & Meal Entries
CREATE INDEX IF NOT EXISTS idx_daily_nutrition_user_date 
ON public.daily_nutrition (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_meal_entries_nutrition_id 
ON public.meal_entries (daily_nutrition_id, created_at ASC);

-- 4. Analytics & Telemetry Time-Series
CREATE INDEX IF NOT EXISTS idx_telemetry_events_user_time 
ON public.analytics_events (user_id, timestamp DESC);

-- 5. Knowledge Base Vector Index (HNSW for sub-5ms cosine retrieval)
CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_hnsw 
ON public.knowledge_documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
