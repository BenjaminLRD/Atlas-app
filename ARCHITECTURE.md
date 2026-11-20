# Atlas — Technical Architecture & Implementation Blueprint

---

## 1. High-Level System Architecture

Atlas is built on a **Layered Clean Architecture** that enforces unidirectional data flow, separation of concerns, and an **offline-first** design paradigm:

```
                            UI Presentation Layer
         (Screens, Bento Glass Cards, Modals, Ambient Gradients)
                                    │
                                    ▼
                         State Management Layer
             (FitnessProvider, ProfileProvider, ValueNotifiers)
                                    │
                                    ▼
                          Domain Services Layer
         (TrainingIntelligence, RecoveryAnalytics, NutritionEngine)
                                    │
                                    ▼
                           Repository Layer
    (SupabaseWorkoutRepo, SupabaseNutritionRepo, SupabaseHealthRepo)
                                    │
            ┌───────────────────────┴───────────────────────┐
            ▼                                               ▼
 [ Online: Supabase Cloud ]                     [ Offline: Local Cache ]
 • PostgreSQL 15+ DB with RLS                   • Android Keystore / Keychain
 • Realtime Broadcasts                          • In-Memory RAM Caches (<1ms)
 • Storage Buckets (Media)                      • OfflineActionQueue (Replay)
```

---

## 2. Layer Responsibilities & Contracts

### 1. Presentation Layer (`lib/screens/`, `lib/widgets/`)
- **Stateless & Composable**: Complex screens are split into small, focused sub-widgets (`DashboardHeader`, `TodayHealthCard`, `WaterIntakeCard`).
- **Const Optimization**: Enforces `const` widget constructors to enable Flutter's element tree to skip sub-tree rebuilding during rendering ticks.
- **Isolated Reactivity**: Fine-grained updates (e.g. water intake counter or stopwatch timer ticks) use localized `ValueListenableBuilder` instances rather than full-page `setState()`.

### 2. State Management Layer (`lib/providers/`)
- **`FitnessProvider`**: Central reactive application state orchestrating user progress, active workouts, nutrition summaries, recovery scores, daily briefs, notifications, and leaderboard rankings.
- **`ProfileProvider`**: Manages athlete identity, biometric updates, and theme toggling.
- **Single Source of Truth**: UI screens reactively bind to provider streams and value notifiers without requiring manual screen refreshes or app restarts.

### 3. Domain & Analytics Services (`lib/services/`)
- Encapsulates pure business logic, calculations, and external SDK abstractions:
  - `TrainingIntelligenceService`: Calculates progressive overload, volume distribution, and fatigue index.
  - `RecoveryIntelligenceService`: Computes readiness scores (0–100) based on sleep duration, resting heart rate, and training intensity.
  - `NutritionCalculator`: Implements Harris-Benedict BMR, TDEE, and macro distribution equations.
  - `AIResponseCache`: In-memory LRU cache with 12-hour TTL providing instantaneous prompt deduplication.

### 4. Repository Layer (`lib/repositories/`, `lib/services/supabase/`)
- Abstract interfaces decouple domain services from concrete persistence engines:
  - `WorkoutRepository`, `NutritionRepository`, `HealthRepository`, `CommunityRepository`, `GoalRepository`.
- **Cloud-First with Local Fallback Pattern**: Repositories attempt cloud synchronization to keep local caches fresh; if offline or if a network timeout occurs, they fall back immediately to hardware-encrypted local storage with zero UI interruption.

### 5. Data & Storage Layer (`lib/data/`, `lib/services/storage/`)
- **3-Tier Cache Hierarchy**:
  1. **Tier 1 (RAM / In-Memory)**: `<1ms` synchronous access for high-frequency widget builds.
  2. **Tier 2 (Platform Encrypted Keystore)**: Android Keystore (`EncryptedSharedPreferences`) and Apple Keychain (`flutter_secure_storage`) for persistent token, health metric, and profile storage.
  3. **Tier 3 (Cloud PostgreSQL / Supabase)**: Remote storage with PostgreSQL Row Level Security (RLS) policies.

---

## 3. Project Directory Structure

```
lib/
├── app_theme.dart               # Visual identity, typography, light/dark color palettes
├── main.dart                    # Application entry point, error hooks, and bootstrap
├── config/                      # Environment settings (AppConfig, .env, feature flags)
├── data/                        # Local storage, dependency composition root, static seed data
├── models/                      # Immutable domain models and JSON serialization logic
│   ├── app_user.dart            # Authenticated user model (zero credentials)
│   ├── fitness_context.dart     # AI fitness context snapshot
│   ├── health_metric.dart       # Daily telemetry and biometric records
│   ├── user_goal.dart           # Fitness goals and target macros
│   ├── user_profile.dart        # Athlete profile characteristics
│   └── workout_history.dart     # Workout logs, sets, and PR entries
├── navigation/                  # Shell navigation, tab synchronization, route definitions
├── providers/                   # Reactive state containers (FitnessProvider)
├── repositories/                # Abstract data repository interfaces
├── screens/                     # Primary top-level screens and feature destinations
│   ├── dashboard_screen.dart    # Home metrics, recovery cards, and readiness overview
│   ├── diet_plan_screen.dart    # Nutrition analytics and meal logging dashboard
│   ├── login_screen.dart        # Authentication screen
│   ├── profile_screen.dart      # User profile, body composition, and achievements
│   └── workout_session_screen.dart # Active training session with rest timers
├── services/                    # Domain logic, AI engine, hardware telemetry, observability
│   ├── ai/                      # Gemini provider (via ai-proxy), prompt builder, AIResponseCache
│   ├── health/                  # Health Connect, wearable sync, and recovery service
│   ├── monitoring/              # Crash reporting, performance tracker, PII sanitizer
│   ├── offline/                 # OfflineActionQueue and background sync manager
│   ├── storage/                 # SecureStorageService and migration engine
│   └── supabase/                # PostgreSQL schema, RLS policies, and cloud repositories
└── widgets/                     # Reusable modular UI components, bento cards, and charts
    ├── coach/                   # AI Coach conversation widgets and suggestion chips
    ├── common/                  # AppCard, AppButton, AppGlass, MetricCard, AmbientBackground
    ├── error/                   # ErrorCard, RetryButton, ErrorMessageMapper
    ├── health/                  # TodayHealthCard and recovery breakdown rings
    └── nutrition/               # FoodSearchSheet, MealCard
```

---

## 4. Key Engineering Decisions & Rationale

### Decision 1: Offline-First Architecture & Action Replay
- **Context**: Athletes frequently train in gym basements or remote locations with spotty cellular reception.
- **Solution**: All user actions (logging a workout set, recording a meal, updating body weight) update local encrypted storage immediately. If offline, the payload is appended to [`OfflineActionQueue`](lib/services/offline/offline_action_queue.dart) and replayed automatically once a connection is re-established.
- **Benefit**: Zero UI lag, 100% data reliability, and no dropped workout sessions.

### Decision 2: Hardware-Level Encrypted Local Storage
- **Context**: Storing biometric health telemetry and authentication tokens in plaintext `SharedPreferences` poses security and compliance risks.
- **Solution**: Implemented [`SecureStorageService`](lib/services/storage/secure_storage_service.dart) backed by **Android Keystore** (AES-256-GCM via `encryptedSharedPreferences`) and **Apple Keychain** (Hardware Secure Enclave with `first_unlock` accessibility).
- **Benefit**: Protects sensitive user data against physical device extraction and unauthorized inspection.

### Decision 3: Row Level Security (RLS) Multi-Tenant Isolation
- **Context**: Cloud database queries must strictly isolate private athlete records.
- **Solution**: Enforced PostgreSQL Row Level Security across all private tables (`profiles`, `workouts`, `nutrition_logs`, `health_metrics`, `user_goals`) with `auth.uid() = user_id`. Public tables (`community_posts`, `challenges`) allow public read access while restricting mutations to record owners.
- **Benefit**: Zero possibility of data cross-contamination between users at the database engine level.

### Decision 4: Modular AI Layer & In-Memory Response Caching
- **Context**: Repetitive AI prompts generate redundant network traffic, latency, and API costs.
- **Solution**: Built [`AIResponseCache`](lib/services/ai/ai_response_cache.dart) utilizing an LRU cache with a 12-hour TTL. Repeated queries are served in `<1ms` without network roundtrips.
- **Benefit**: Sub-second UI response times, reduced API expenditure, and enhanced mobile battery life.

### Decision 5: Production Observability with Automated PII Redaction
- **Context**: Capturing runtime crash telemetry without inadvertently logging private health metrics or authentication secrets.
- **Solution**: Built [`MonitoringManager`](lib/services/monitoring/monitoring_manager.dart) with recursive attribute sanitization. All error payloads automatically strip keys containing `password`, `token`, `dob`, `heartRate`, `sleepMinutes`, or `healthMetric` before dispatching to crash reporting services.
- **Benefit**: Production observability without compromising athlete privacy or regulatory compliance.
