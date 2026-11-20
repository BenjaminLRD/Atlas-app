# Atlas — Work Checklist

Audit of the codebase against the product vision (AI coach, community, Ranked mode,
smart camera, heart-rate and sleep sensors). Written 2026-10-07.

Updated 2026-10-08 after steps 1–5 (branch `atlas-hardening`): analyzer clean with `--fatal-infos`; 1,296 tests pass, 4 opt-in live tests skipped.

Legend: **Real** = works against a real service/device · **Simulated** = UI exists but data is hard-coded or generated · **Missing** = not in the code.

## Status at a glance

| Area | Status | Notes |
| --- | --- | --- |
| Accounts | Real | Supabase Auth email/password (was local-only, any password worked) |
| Cloud data sync | Real | Profile, workouts, nutrition, goals via outbox; needs `supabase db push` |
| AI coach chat | Real | Gemini through the `ai-proxy` Edge Function; needs deploy |
| Food photo scanning | Real | Gemini Vision through `ai-proxy` |
| Barcode scanner | Real | `mobile_scanner` + Open Food Facts |
| Heart rate / sleep / scale | Real | Apple Health / Health Connect via `health`; needs device testing |
| Uploaded-video squat analysis | Real | ML Kit Pose Detection, squat only |
| Live camera form coach | Real | `camera` + on-device ML Kit; squat, bench, deadlift, overhead press, push-up, curl; needs device testing |
| Gym machine recognition | Missing | Nothing in `lib/` |
| Ranked mode | Real | Milestones verified on the server, video proof for top levels; needs deploy |
| Community | Real | Supabase feed, likes, comments, report & block; needs deploy |
| Subscriptions (Atlas Pro) | Real | RevenueCat + store prices; needs RevenueCat and Play setup |

## 1. Security (do first)

- [x] **Stop shipping `.env` inside the app.** Config now comes from `--dart-define-from-file=.env`; `flutter_dotenv` removed.
- [x] Move Gemini calls behind `supabase/functions/ai-proxy`. Debug builds may use a developer key, sent in a header, never the URL.
- [ ] Deploy it: `supabase db push`, `supabase secrets set GEMINI_API_KEY=...`, `supabase functions deploy ai-proxy` (Supabase CLI was not available here, so the function is untested).
- [ ] **Rotate the Gemini key.** The real key was hardcoded in `test/unit/gemini_ai_provider_test.dart` (now removed) and is still in local git history (commit `7620af9`, not pushed). Also delete `GEMINI_API_KEY` from your local `.env`, or `--dart-define-from-file=.env` will compile it into debug builds.
- [x] Remove `SUPABASE_SERVICE_ROLE_KEY` from `.env.example` (it was never in the local `.env`).
- [x] Server-side daily quotas per feature and tier (`ai_usage` table, `consume_ai_quota`).
- [x] Users can no longer set their own `profiles.subscription_tier` (trigger).
- [x] Android auto-backup of app data disabled.
- [x] Removed fake Google/Apple sign-in buttons, which logged every user into one shared account.
- [ ] Real Google/Apple sign-in through Supabase OAuth (needs provider setup and deep links).

## 2. Housekeeping

- [x] Commit the 98 uncommitted changes (branch `atlas-hardening`).
- [x] Rename the Dart package to `atlas`, app brand strings, desktop runners and docs.
- [x] App ID set to `com.atlasfitness.app` on Android, iOS, macOS and Linux.
- [ ] Replace placeholder `aizawlgym.com` URLs and emails (API, support, Sentry, billing verify) with a real domain.
- [x] Docs use one ladder: Bronze → Silver → Gold → Platinum → Diamond → Elite.
- [x] AI provider: Gemini (deck updated to match).
- [x] Apple Health / Health Connect providers are real now (they were documented as "production-ready" but returned fixed numbers).
- [ ] Resolve the "coming soon" stubs: Share Workout and AI Workout Review (`widgets/progress/workout_timeline.dart`), cardio sensor sync (`cardio_session_screen.dart`).

## 3. Backend and data

Finding: the old "Supabase" layer (`SupabaseClientManager`) was an in-memory simulation; nothing ever reached a real database, and sign-in was local-only (any email and password worked).

- [x] Real sign-in and sign-up with Supabase Auth (`CloudAuthRepository`); the login screen now shows errors instead of letting failed logins through, and has a Create account mode.
- [x] Cloud saving for profile, workouts, workout history, nutrition days and goals: saved locally first, then pushed through a persistent outbox (`CloudSyncQueue`) that retries until it succeeds.
- [x] Restore on sign-in and app start (`CloudSyncCoordinator`): uploads existing on-device data once, then pulls the account's data. Unsynced local edits are never overwritten.
- [x] A different account signing in on the same device no longer sees or uploads the previous account's data.
- [x] Clean baseline migration; the colliding old migrations (duplicate version numbers, a teardown script that would have dropped tables) moved to `supabase/archive/`.
- [x] `delete-account` Edge Function (required by both app stores).
- [ ] Deploy: `supabase db push`, `supabase functions deploy delete-account` (not run here: no Supabase CLI or network access).
- [x] Settings: Delete Account works (was a "coming soon" label); Log Out now actually signs out of the account (it only flipped a local flag).
- [ ] Remove the simulated layer once nothing depends on it: `SupabaseClientManager`, `services/supabase/supabase_*_repository.dart`, `SyncQueueService` adapters, `OfflineActionQueue`. Many existing tests exercise it, so this needs its own pass.
- [ ] Move community, challenges, leaderboard and coach memory to real tables (see step 8 / Ranked).
- [ ] Email confirmation: decide whether to require it (Supabase setting); the app already handles both.
- [x] Forgot Password sends a real reset email (it only showed a success message).
- [ ] Password reset link target: set the Supabase redirect URL to a web page or app deep link where users choose a new password.
- [x] Splash screen requires a real session when accounts are enabled.
- [ ] Verify the Android build locally: `flutter build apk --debug` (Gradle could not run in this environment).

## 4. Health sensors (heart rate and sleep)

- [x] `health` package added; `PlatformHealthReader` reads steps, active calories, heart rate, resting HR, HRV (SDNN on iOS, RMSSD on Android) and sleep stages (falls back to sleep sessions) from HealthKit / Health Connect.
- [x] Dashboard and Today card use real data on phones (`PlatformHealthService`); missing values show as no data instead of samples.
- [x] Apple Health / Health Connect providers in both wearable layers now read real data (they returned hard-coded numbers such as 9,240 steps on an "Apple Watch Ultra").
- [x] Android: Health Connect read permissions, rationale intent, Android 14 permission-usage alias, `minSdk 26`, `FlutterFragmentActivity`. iOS: usage descriptions.
- [ ] iOS: open `ios/Runner.xcworkspace` in Xcode, Runner target → Signing & Capabilities → add **HealthKit**.
- [ ] Test on real devices (Health Connect app on Android, a watch writing to Apple Health on iOS).
- [ ] `HealthMetrics` has invented defaults for missing values (7.5 h sleep, HRV 65 ms, HR 60/68); make its fields nullable so the recovery score can say "not enough data" instead of scoring defaults.
- [x] Body composition screen and smart-scale sync use real readings (were fixed values).
- [x] Device list offers the phone's health store only; Fitbit/Garmin devices arrive through it (the fake Fitbit/Garmin links are no longer shown).
- [ ] Remove remaining simulated health code: `LocalHealthService` weekly samples and `HealthMetric.sample()` (desktop/tests), unused Garmin/Fitbit provider classes, `MockWearableService` outside tests.
- [ ] Consolidate the three health layers (`HealthService`, `HealthSyncService`/`HealthProvider`, `WearableService` + two wearable managers) into one.
- [ ] Sync health readings to Supabase (currently on-device only).
- [ ] Health Connect only returns 30 days of history by default; request `READ_HEALTH_DATA_HISTORY` if longer trends are needed.

## 5. Smart camera

- [x] **Live camera form coach:** `camera` package streams frames into ML Kit (`LivePoseCamera`); the simulated live view and four unreachable mock screens are gone.
- [x] Form rules rebuilt: body-relative measures, best-visible side, front-on knee cave, sag vs pike, per-exercise rep counting, partial reps flagged, no invented reps or confidence.
- [ ] Test live tracking on real phones (both cameras, portrait), and tune thresholds with real lifters.
- [x] Overhead press checks added; bench press and deadlift checks reworked.
- [ ] Deadlift back rounding cannot be measured from ML Kit's landmarks (no spine points); consider a dedicated model or leave out.
- [x] Safety copy and per-exercise camera placement tips on the live view.
- [ ] **Gym machine recognition (new):** collect and label machine photos, train a TFLite model (or prototype with Gemini Vision first), add machine info pages (muscles, setup, how-to).
- [ ] Food photo: show confidence and let users correct portions before logging.

## 6. Ranked mode

- [x] Stats and milestones: Strength (bench, squat, deadlift, overhead press as bodyweight multiples, men's/women's standards), Endurance (push-ups), Cardio (5 km), Consistency (workouts in 28 days); 5 levels each, shared catalog JSON.
- [x] One ladder: Bronze → Champion, divisions III–I; XP no longer changes rank. `UserRank` and the XP rank structure removed.
- [x] Server-computed rank: `ranked-sync` evaluates synced data; database derives rank from approved claims; users cannot write claims or rank.
- [x] Anti-cheat: strength and push-up levels 4–5 need a proof video, reviewed via `ranked_review_queue`.
- [x] Verified leaderboard from `ranked_profiles`.
- [ ] Deploy: `supabase db push`, `supabase functions deploy ranked-sync`.
- [ ] Reviewer workflow: who reviews videos, and a small admin screen instead of editing rows in the dashboard. Consider using the form coach to pre-check videos.
- [ ] Tune milestone targets with real users; decide on standards for non-binary athletes (currently the men's table applies unless gender starts with "f").
- [ ] Workout weights and body weight are assumed to be in the same unit (true today: the app never converts). Keep it that way or store kg internally.
- [ ] Seasons, weekly brackets and regional/friends leaderboards (`season_service.dart`, `LeaderboardService` and `SocialAthleteRank` still use mock data and old tier names; replace with community in step 8).
- [ ] Body weight at the time of a lift: milestones use the current profile weight.

## 7. AI coach

- [x] Server-side proxy (see Security) with usage metering per tier.
- [ ] Safety guardrails: injuries, medical conditions, eating disorders; refer to professionals.
- [ ] Persist `FitnessMemory` in Supabase so it survives reinstalls and syncs across devices.
- [ ] Track cost per user and response quality (the `evaluation` / `monitoring` folders are a start).

## 8. Community

- [x] Real feed on Supabase (posts, photos, likes, comments) with author name and rank from Ranked.
- [x] Moderation: report and block reach the server; blocking enforced by RLS both ways; 3 reports hide content pending review (`community_review_queue`).
- [x] Fixed fake author identity, stock-photo fallback and invented post numbers.
- [ ] Deploy: `supabase db push` (community migration).
- [ ] Moderator workflow and community guidelines / terms of use (Play UGC policy); respond to reports promptly.
- [ ] Video posts (currently disabled when signed in), feed pagination, realtime updates, push notifications for social activity.
- [ ] Following/friends, challenges and leaderboards in the community tab still use local/mock data (`SocialGraphService`, `SocialChallengeService`, `LeaderboardService`, `SocialAthleteRank`).

## 9. Monetization and release

- [x] RevenueCat billing with store regional pricing; webhook sets the server tier; no free Pro in release builds.
- [x] Removed the fake UPI payment screen and dead premium screens.
- [x] Release signing config; privacy policy and in-app privacy summary match the app; `docs/RELEASE_ANDROID.md`.
- [ ] RevenueCat account, Play products and regional prices, webhook secret (see `docs/RELEASE_ANDROID.md`).
- [ ] Upload keystore, Play Console app content (data safety, Health Connect declaration, account deletion web link, content rating), internal testing track.
- [ ] Publish the privacy policy at a public URL with the placeholders filled in.
- [ ] Crash reporting: `SentryCrashService` is a stub that sends nothing; connect Sentry or Firebase Crashlytics, or remove it.
- [x] CI uses Flutter 3.44 and runs the full test suite.
- [ ] CI's `dart format --set-exit-if-changed` fails on ~200 files that were already unformatted before this work; run `dart format .` once in its own commit.
- [ ] Add repository secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_ANDROID_KEY` for the release build.
