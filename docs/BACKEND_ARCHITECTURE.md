# Atlas Backend Service Architecture (Million User Scale)

## 1. Executive Architecture Overview

To transition Atlas from a single-region client application to an enterprise-grade platform capable of serving **1,000,000+ active athletes**, the backend employs a decoupled, modular service-oriented architecture with event-driven asynchronous messaging, edge caching, and independent horizontal autoscaling.

```
                           [ CDN Edge (Cloudflare / Fastly) ]
                                          │
                                 [ API Gateway / Envoy ]
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
          [ User / Auth Service ]  [ Workout Service ]  [ Nutrition Service ]
                    │                     │                     │
                    └──────────┬──────────┴──────────┬──────────┘
                               │                     │
                               ▼                     ▼
                     [ Event Bus / Kafka ]  [ Supabase / Postgres Primary ]
                               │                     │
                    ┌──────────┴──────────┐   ┌──────┴──────┐
                    ▼                     ▼   ▼             ▼
          [ Atlas AI Gateway ]    [ Analytics Service ] [ Read Replicas (x3) ]
```

---

## 2. Microservice Boundaries & Contracts

### 2.1 User & Identity Service
- **Domain**: Authentication, subscription tiers, athlete profiles, security keys, privacy consents.
- **Data Store**: Supabase Auth + `profiles` table.
- **Contract**: REST / GraphQL for profile mutations; JWT claims for stateless auth validation.

### 2.2 Workout Intelligence Service
- **Domain**: Exercise database, active workout tracking, progressive overload algorithms, 1RM calculators, volume tracking.
- **Data Store**: PostgreSQL `workouts`, `exercise_logs`, `exercise_prs`. Partitioned monthly by `date_completed`.
- **Scaling**: Keyset cursor pagination; Redis caching for user personal records.

### 2.3 Nutrition & Metabolic Service
- **Domain**: Food database search, barcode lookup, macro arithmetic, calorie expenditure estimates.
- **Data Store**: PostgreSQL `nutrition_logs`, `meal_entries`, `food_cache`.
- **Scaling**: Read-heavy; 99% of food queries served via Redis in-memory cache.

### 2.4 Dedicated Atlas AI Gateway Service
- **Domain**: Gemini LLM interaction, RAG vector retrieval (pgvector / Supabase Vector), memory persistence, prompt synthesis, response evaluation.
- **Data Store**: Vector embeddings (`knowledge_embeddings`), short-term / long-term memory partitions (`fitness_memories`).
- **Scaling**: Async priority queues, tiered model routing (Flash vs Pro), response caching, and concurrency rate limiting.

### 2.5 Analytics & Telemetry Service
- **Domain**: Real-time quality audits, performance telemetry, bandit experiment tracking, user feedback loops.
- **Data Store**: ClickHouse / TimescaleDB for time-series events; cold storage archive in AWS S3 / Cloudflare R2.

### 2.6 Notification & Real-Time Service
- **Domain**: Proactive coach notifications, workout reminders, live socket sync, push dispatching via FCM / APNs.
- **Data Store**: Redis pub/sub + RabbitMQ for scheduled briefings.

---

## 3. Database Sharding & Scaling Strategy

1. **Read/Write Splitting**:
   - 1 Primary Read/Write Postgres instance for transactional writes.
   - 3 Read Replicas distributed across availability zones for query loads.
2. **Table Partitioning**:
   - `workout_history` partitioned by `RANGE (date_completed)` (Monthly chunks).
   - `telemetry_events` partitioned by `RANGE (timestamp)` (Weekly chunks) with automated S3 cold storage archival after 90 days.
3. **Composite Indexing**:
   - Dedicated indexes on `(user_id, date_completed DESC)` and `(user_id, importance_score DESC)` to maintain sub-10ms query execution at scale.

---

## 4. Disaster Recovery & High Availability SLA
- **Target Uptime**: 99.95% Availability.
- **RPO (Recovery Point Objective)**: < 1 minute (Continuous WAL streaming).
- **RTO (Recovery Time Objective)**: < 15 minutes (Automated multi-region failover).
