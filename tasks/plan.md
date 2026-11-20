# Plan: reliable nutrition lookup

Spec: `../SPEC.md`. Checklist: `todo.md`. Rule: one task at a time, stop for review after each.

## Findings that shape the plan

- `FoodItem` already stores `unknownNutrients` and `servingUnit`, and JSON reading is defaulting and tolerant, so an additive field is safe. It has no explicit nutrition basis. `servingUnit` is overloaded: `'grams'`/`'ml'` mean "values are per 100", while `'bowl'`, `'piece'`, `'serving'` mean "values are per one".
- OFF parsing hardcodes `servingUnit: 'grams'` for every product, so drinks are labelled per 100 g. `NutritionCalculator` treats `g`, `grams` and `ml` identically.
- The barcode result sheet starts with `_unit = food.servingUnit` and `_quantity = 100`.
- Photo flow has no database step; the AI prompt returns no brand, variant or pack size.

## Dependency graph

```
T1 basis field ──> T2 OFF parser sets basis ──> T3 safe scaling + UI text ──> [CP1 device]
                                                       │
T4 provenance + badge kinds ──────────────┐            │
T5 matcher (pure) ────────────────────────┼──> T7 lookup orchestrator ──> [CP2]
T6 search client (+ fixture) ─────────────┘            │
T8 AI prompt fields (optional, compatible) ────────────┘
                                         T7 ──> [CP3 before UI] ──> T9 photo UI ──> T10 docs/attribution ──> [CP4 device]
```

T4, T5, T6 and T8 are independent of each other; do them in the listed order.

## Phase A: correctness (first checkpoint)

**T1 Nutrition basis in the model.** Add an optional `nutritionBasis` (per 100 g, per 100 ml, per serving, unknown) to `FoodItem` with `copyWith`/JSON. A missing key derives a safe value from legacy `servingUnit` (`grams`/`g` gives per 100 g, `ml` gives per 100 ml, anything else gives per serving). No behaviour change.
- Accept: old cached/saved JSON loads identically; `unknownNutrients` handling untouched; round trip keeps basis.
- Verify: new unit tests plus `food_item`/cache tests still pass.

**T2 OFF parser sets basis.** Decide ml vs g from the product's `serving_size`/`quantity` text and beverage category tags; unknown when neither says. Set `servingUnit` accordingly. Do not touch legacy readers.
- Accept: a drink fixture is per 100 ml; a solid is per 100 g; an ambiguous product is unknown basis; unknown nutrients unchanged.
- Verify: parser tests with fixtures, including kJ-only and per-serving-only products.

**T3 Safe scaling and honest text.** `NutritionCalculator` refuses cross-basis scaling (typed result, no number) and never guesses density. The barcode sheet says "per 100 ml" or "per 100 g", and shows per-100 values only when the basis is unknown.
- Accept: ml product logged in ml scales; logged in g is refused with a clear message; unknown basis does not scale.
- Verify: calculator tests, sheet widget tests at 360x640, full suite, analyzer.

**CHECKPOINT 1.** Analyzer clean, full suite green, owner installs the APK and scans a drink and a solid product (steps supplied).

## Phase B: source search and matching (incremental)

**T4 Provenance and labels.** Add a source kind (OFF barcode, user-confirmed match, AI estimate, user entry) and an optional per-field source map to `FoodItem`; add `SourceBadge` kinds "Exact product, partial nutrition" and "Possible match". Absent map means the whole item has one source.
- Accept: no existing label text changes; badge tests cover each kind.

**T5 Matcher (pure, no network).** Normalise brand/name/variant/size; return exact, possible (ranked) or none. Variant words (zero sugar, diet, light, etc.) must agree both ways. Region adds weight but never decides.
- Accept: fixtures for same brand/different variant (possible, not exact), size mismatch, transliterated names, empty brand.

**T6 Search client.** Search-a-licious `GET /search` with `q`, `langs`, `page_size`, `fields`. Step 0: capture one real response as a fixture (single read-only request) to verify field names and the India filter. Throttle to at most one request per 6 s, timeout, typed errors (offline, 429/503, bad JSON, empty), User-Agent.
- Accept: `MockClient` tests for every error; never fires per keystroke.

**CHECKPOINT 2.** Matcher and client reviewed with fixtures; no UI change yet.

**T7 Lookup orchestrator.** AI result to query to matcher to `MatchResult` (exact | possible | none | error), India first then widened and labelled. Caching per SPEC section 8.
- Accept: cache rules tested; ambiguous never stored as verified.

**T8 AI prompt extension (conditional).** Add optional brand, variant, pack size and packaged flag to the client prompt and parser. Old responses still parse. No `ai-proxy` change.
- Accept: existing food photo tests unchanged; new fields optional.

**CHECKPOINT 3.** Full suite green; review before touching the photo UI.

**T9 Photo UI.** Candidate picker, new badges, errors, fallbacks to the AI estimate, manual entry always visible. Reuse `food_result_parts.dart`.
- Accept: 360x640 without overflow; every state reachable in tests.

**T10 Docs and attribution.** CHANGELOG, OFF attribution/licence text, privacy note (product text sent to OFF), User-Agent version.

**CHECKPOINT 4.** Owner device test: barcode, photo (exact, possible, none), offline, rate-limit message, manual entry, logging, AI chat.

## Risks

| Risk | Mitigation |
|---|---|
| `servingUnit` overload breaks logging if changed carelessly | T1 is additive; T2 changes only the OFF parser; regression tests first |
| Wrong ml/g call from sparse OFF data | Unknown basis is a valid outcome; no scaling then |
| OFF 503/ban from search volume | User-initiated only, throttle, cache, negative cache |
| Search-a-licious field names differ from assumption | Fixture step in T6 before code |
| Fuzzy match shown as verified | Matcher tests plus UI label tests |
| Legacy cache entries | Back-compat tests in T1 |
