# Supabase backend

Everything here is taken from `supabase/migrations/` and `supabase/functions/`. Nothing in this page was applied or changed by the documentation work.

## Database (14 tables, Row Level Security on every table)

```mermaid
erDiagram
  AUTH_USERS ||--|| PROFILES : "id"
  AUTH_USERS ||--o{ WORKOUT_SESSION_RECORDS : "user_id"
  AUTH_USERS ||--o{ WORKOUT_HISTORY_RECORDS : "user_id"
  AUTH_USERS ||--o{ CARDIO_SESSION_RECORDS : "user_id"
  AUTH_USERS ||--o{ NUTRITION_DAY_RECORDS : "user_id"
  AUTH_USERS ||--o| FITNESS_GOAL_RECORDS : "user_id"
  AUTH_USERS ||--o{ AI_USAGE : "user_id"
  AUTH_USERS ||--o| RANKED_PROFILES : "user_id"
  AUTH_USERS ||--o{ RANKED_CLAIMS : "user_id"
  AUTH_USERS ||--o{ COMMUNITY_POSTS : "user_id"
  COMMUNITY_POSTS ||--o{ COMMUNITY_LIKES : "post_id"
  COMMUNITY_POSTS ||--o{ COMMUNITY_COMMENTS : "post_id"
  COMMUNITY_POSTS ||--o{ CONTENT_REPORTS : "post_id"
  COMMUNITY_COMMENTS ||--o{ CONTENT_REPORTS : "comment_id"
  AUTH_USERS ||--o{ USER_BLOCKS : "blocker_id and blocked_id"

  PROFILES {
    uuid id PK
    text email
    text full_name
    text subscription_tier
    jsonb data
  }
  AI_USAGE {
    uuid user_id PK
    date usage_date PK
    text feature PK
    int request_count
  }
  WORKOUT_HISTORY_RECORDS {
    uuid user_id PK
    text id PK
    timestamptz completed_at
    jsonb data
  }
  CARDIO_SESSION_RECORDS {
    uuid user_id PK
    text id PK
    timestamptz started_at
    jsonb data
  }
  NUTRITION_DAY_RECORDS {
    uuid user_id PK
    date log_date PK
    jsonb data
  }
  COMMUNITY_POSTS {
    uuid id PK
    uuid user_id FK
    text type
    text title
    int likes_count
    int comments_count
    bool hidden
  }
  RANKED_CLAIMS {
    uuid user_id PK
    text milestone_id PK
    int level PK
    text status
  }
```

`WORKOUT_SESSION_RECORDS`, `FITNESS_GOAL_RECORDS`, `RANKED_PROFILES`, `RANKED_STAT_RULES`, `COMMENTS`, `LIKES`, `REPORTS` and `USER_BLOCKS` follow the same pattern and are omitted from the field lists to keep the diagram readable.

Design notes:

- The application's own records (workouts, cardio sessions, nutrition days, goals) are stored as a primary key plus a `jsonb data` column, so the client model can evolve without a migration for every field. Rankings and community data use typed columns.
- Every user-owned table references `auth.users` with `ON DELETE CASCADE`, so deleting the user removes their rows.
- `profiles.subscription_tier` can be changed only by the server: a trigger (`protect_subscription_tier`) blocks client updates, and the `revenuecat-webhook` function sets it.
- AI usage is counted per user, day and feature by the database function `consume_ai_quota`.

## Edge Functions

| Function | Purpose | Notes |
|---|---|---|
| `ai-proxy` | The only caller of the Gemini API. Signed-in branch: verifies the user, checks the daily quota, forwards the request. Showcase branch: no user; validates and rebuilds the request, applies limits. | See [ai_request_flows.md](ai_request_flows.md) |
| `delete-account` | Deletes the caller's uploaded files and then the auth user; rows go by cascade | Needs the service key, which exists only on the server |
| `ranked-sync` | Evaluates Ranked milestones from the caller's synced records (never from numbers sent by the app) and records claims | Rank itself is computed by the database from approved claims |
| `revenuecat-webhook` | Receives store purchase events and sets `profiles.subscription_tier` | Authenticated by a shared secret, not by a user token |

## Secrets used by the functions (names only)

`GEMINI_API_KEY`, `SHOWCASE_AI_ENABLED`, `SHOWCASE_PUBLIC_KEYS` (optional), `REVENUECAT_WEBHOOK_SECRET`. The platform injects `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` (and the newer publishable and secret key variables). No secret values are stored in this repository.
