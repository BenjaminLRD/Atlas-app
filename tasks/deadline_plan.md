# Deadline plan: finish Atlas by Wednesday night

Deadline: **Wednesday 2026-11-18, 23:59** (set 2026-11-14, Saturday). After that time the app is frozen: only fixes for crashes or data-loss bugs.

Order of work, set by the owner: first make every feature work properly, then declutter the UI (too much to read, unclear where a new user starts). Rules in `CLAUDE.md` still apply: one small change at a time, stop for review after each task, no commits without permission, owner phone checks are the only device proof.

## Feature inventory (from `lib/screens`)
Each feature gets one status: works / broken / unverified. Nothing counts as "works" until the owner has tried it on the phone.

| Area | Screens |
|---|---|
| Account | splash, login, forgot password, onboarding, edit profile, profile, settings, subscription |
| Workouts | workout plan, weekly plan, overview, detail, session, history, exercise library and detail, machine scanner, equipment setup, cardio activity and session |
| Nutrition | diet plan, unified food scanner (photo, barcode, manual), weight goal setup, weight gain plan |
| AI | AI coach and chat, daily brief, recovery, health dashboard, personalization insights, Atlas intelligence dashboard, body composition, form coach |
| Social | community, friends, challenges, ranked, public profile, notifications, wearable devices |

## Schedule
| When | Goal | Done means |
|---|---|---|
| Sat 14 Nov | Audit: run `flutter analyze --fatal-infos --no-pub` and the full suite; list every feature with its status; collect known bugs from `docs/WORK_CHECKLIST.md`, `tasks/todo.md` and the owner's own phone notes | Written bug list ranked by how much it blocks a new user; no code changed except obvious test failures |
| Sun 15 Nov | Fix the blocking bugs in account, workouts and nutrition (the daily path) | Each fix has a test; analyzer clean; owner installs the APK and checks login, one workout, one logged meal |
| Mon 16 Nov | Fix the rest: AI, recovery, social, subscription. Anything that cannot be fixed by tonight is hidden behind a flag or removed from the menu, not left half working | Every visible feature either works on the phone or is not visible |
| Tue 17 Nov | Declutter: define the first-run path (what a new user sees first and what they do first), cut or collapse secondary screens and text, keep the design system | Owner walks the app as a new user and can say where to start without help |
| Wed 18 Nov | Freeze day: full suite, analyzer, release build, full owner phone pass using `tasks/phone_test_nutrition.md` plus a short checklist for the other areas; fix only what that pass finds | Signed-off APK by 23:59; remaining items written down as post-deadline |

## Rules for the week
- **Cut, don't polish:** a feature that is not working by Monday night is hidden, not rescued on Wednesday.
- **No new features** and no USDA integration (Phase 4) before the deadline.
- **Phone checks are the owner's.** I can run tests and builds, not verify behaviour on a device.
- **Decluttering keeps data:** hiding a screen must not delete stored user data.
- **Risks:** the working tree has about 330 uncommitted changes, so nothing here is safely backed up until you decide to commit; the owner phone tests listed in `tasks/todo.md` are still open.

## Decisions (owner, 2026-11-14)
- **Purpose:** presentation and showcase of the app. Not a store launch, so no Play listing, store policies or Play signing.
- **Delivery:** a phone-installable release APK is enough.

What this changes:
- **Monday's cut list** is decided by the demo: keep what shows well and works reliably live; hide anything that is slow, needs a paid key, depends on live AI or network luck, or that you would not present.
- **Wednesday's pass** is a full rehearsal of the demo path on the phone, including a run with poor or no connection. The existing `docs/demo_script.md` is the starting point and gets updated to match the final app.
- **Declutter on Tuesday** targets the demo path: a first screen that makes the starting point obvious, and few words per screen.
- **Not needed:** Play signing, privacy policy and third-party notices (T10), store assets.

## Open question
Which 4 to 6 features will you actually present? Naming them lets Saturday's audit rank bugs by what the demo needs.
