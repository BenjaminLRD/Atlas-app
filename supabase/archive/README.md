# Archived migrations

These scripts are **not** applied by `supabase db push`.

They were kept for reference when the schema was rebuilt on 2026-10-07:

- Several files shared one version prefix (`20260826`, `20260827`), which the
  Supabase CLI rejects.
- `20260826_..._database_schema_b4.sql` and `20260826_..._schema_v2.sql`
  both created `profiles`, `workout_sessions`, `nutrition_logs` and others with
  different columns and id types; whichever ran first won.
- `..._schema_v2_down.sql` is a teardown script. In `migrations/` it would have
  run as a normal migration and dropped the tables.
- The app never talked to these tables: its Supabase layer
  (`SupabaseClientManager`) was an in-memory simulation.

The live schema starts at `migrations/20261007000000_atlas_baseline.sql`.
Community, challenges, leaderboards and analytics tables will be added back,
one migration each, when those features move to the real backend.
