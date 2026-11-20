# Todo: reliable nutrition lookup

Details and acceptance criteria: `plan.md`. Spec: `../SPEC.md`. Stop for review after each task.

**Deadline: Wednesday 2026-11-18, 23:59.** Every feature working first, then UI declutter. Day-by-day schedule: `deadline_plan.md`.


## Demo hardening (2026-11-14 onward; audit in `audit_2026-11-14.md`)
- [x] Phase 1: removed fabricated health and wearable readings (fake providers deleted, missing values stay null, AI tools no longer invent sleep, heart rate or steps)
- [x] Phase 2: real step counter (`pedometer` package, Activity Recognition permission, per-day ledger, Health Connect kept separate, one daily total for dashboard, activity screen, weekly chart, AI context and recovery). Owner phone test: `phone_test_steps.md`
- [x] Phase 3: recovery and readiness use recorded data only (missing sleep, HRV or heart rate means "unavailable", never a neutral number). Daily brief, prediction engine, 4-pillar recovery, coach engines, notifications, AI tools and chat answers updated; `test/unit/recovery_missing_data_test.dart`. Owner phone check still open.
- [ ] Gradle: release build needs `GRADLE_OPTS="-Dorg.gradle.project.kotlin.incremental=false"` on this machine (temporary; not a project change). Cause not caused by the move to E: or stale caches (see report 2026-11-14).
- [x] Phase 4: sample community always available, flagged `isSample`, labelled SAMPLE, never stored among real posts or sent to Supabase (tests pass; phone check open)
- [x] Phase 5: approved profile and post pages implemented (real profiles show only provided info; sample content labelled; phone check open)

## Before coding
- [x] Research OFF usage rules (SPEC section 2)
- [x] Save SPEC.md, tasks, constraints in CLAUDE.md
- [x] Branding cleanup and OFF User-Agent (Atlas/1.1.0, approved contact)
- [ ] Owner: fill OFF API usage form
- [ ] Owner: real-device check of the scanner redesign (APK)

## Phase A: correctness
- [x] T1 Nutrition basis field in `FoodItem` (additive, back-compat JSON)
- [x] T2 OFF parser sets basis (g / ml / unknown)
- [x] T3 Safe scaling and "per 100 ml / g" text (mass vs volume refused; per-piece units unchanged, see report)
- [ ] CHECKPOINT 1: analyzer, full suite, owner phone test (drink + solid)

## Phase B: search and matching
Built together in one pass (tests green, full suite 2,148; not yet seen on a phone):
- [x] T4 Provenance: `FoodItem.nutritionSource` + `sourceUrl`; unknown nutrients; badge labels. (A per-field source map was not needed: a result always comes from one source, nothing is merged.)
- [x] T5 Matcher (pure) with a real Open Food Facts fixture
- [x] T6 Search client (real response captured 2026-10-23, 6 s throttle, typed errors)
- [x] T7 Lookup orchestrator (India first, then widened and never exact)
- [x] T8 AI prompt fields (brand, variant, packaged flag, label size); zeros from a photo are unknown
- [x] T9 Photo UI: picker, source labels, confirm-size gate, unknown as dashes, manual editing
- [x] Integrity Phase 1: nutrient status layer, one formatter, dashes for unknown everywhere, saturated fat and salt, macro lower bounds, "source not recorded" for older entries, regression matrix for every nutrient
- [x] Integrity Phase 2: provenance (source, match kind, retrieval time), source note with the community-data warning, barcode read from a photo (check digit), caching
- [x] Integrity Phase 3: per-serving and per-package bases, package and serving sizes from Open Food Facts, scaling through one calculator
- [x] Integrity follow-up: every numeric consumer audited and fixed (recovery, ML inputs, insight rules, briefs, notifications, coach engines, weekly reviews, analytics, weight-goal banner); the all-zero photo rule replaced by explicit `confirmedZero`; audit in SPEC.md
- [ ] Owner phone test: tasks/phone_test_nutrition.md (8 cases)
- [ ] Integrity Phase 4 (separate): USDA FoodData Central through a server-side function only; needs your approval for the backend and a key
- [ ] CHECKPOINT 2/3: owner phone test of the photo flow (Mountain Dew 750 ml, a home meal, offline, a product with no match)
- [ ] Caching rules (SPEC section 8): not built. Each photo of a packaged product searches again.
- [ ] T10 Privacy note (product name and brand are sent to Open Food Facts), `PRIVACY_POLICY.md`, `THIRD_PARTY_NOTICES.md`
- [ ] CHECKPOINT 4: owner phone test (barcode, photo, offline, rate limit, logging, AI chat)
- [x] Community Step 3 (Rankings: real week + sample board) and Step 4 (Challenges: presets, custom, self and sample opponents, Active/Past, real progress only); real-member challenges and weekly_stats SQL are review-only/deferred (phone check open)
- [x] Exercise UI 2026-11-16: 72 custom thumbnails, set timer with saved duration, side/front view toggle (12 exercises), verified YouTube demonstrations (69; 3 say none)
- [ ] Owner phone test: tasks/phone_test_exercise_ui.md
