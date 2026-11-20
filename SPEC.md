# SPEC: Reliable nutrition lookup

Status: approved decisions, implementation not started. Plan: `tasks/plan.md`. Tasks: `tasks/todo.md`.

## 1. Objective

Show real database nutrition for packaged food whenever it exists, scaled to the serving the user picks. Say honestly what each value is: verified database data, partial data, a possible match, or an AI estimate.

Users: Atlas users logging packaged and photographed food, mainly in India.

### Acceptance criteria

1. A barcode found in Open Food Facts (OFF) is shown with its database values, scaled from the per-100 g or per-100 ml basis.
2. A product can be an **exact product match with partial nutrition**. Completeness of nutrition is never a condition for a match. Only the values the database has are shown; the rest stay unknown (a dash), never zero.
3. Nutrition basis (per 100 g, per 100 ml, or unknown) is stored with the food. Values scale only within their basis. No g to ml conversion and no density guessing. Unknown basis: show per-100 values only and do not scale.
4. A photo of a packaged product is matched against OFF by brand, name, variant and pack size.
   - **Exact:** brand, name and variant agree and size agrees when both sides have it. Labelled "Product database".
   - **Possible:** anything less. Shown as a list the user must choose from. Never applied automatically.
   - **None:** the existing AI estimate, labelled unverified.
   - Region alone is never proof of a match.
5. Region: India by default; widen to all regions only if the regional result is insufficient. The widened result is labelled as such.
6. Provenance is kept per field where feasible. Values from different sources are never merged without recording which field came from which source.
7. Timeout, offline, HTTP 429/503, malformed response and an empty result each give a distinct, non-blocking message. Logging and manual entry always stay available.
8. Barcode scan, photo capture, food logging, AI chat, authentication and Supabase behave exactly as before.

## 2. Source strategy (decided; see research notes)

- Primary: OFF product API by barcode (existing).
- Search: **Search-a-licious** (`https://search.openfoodfacts.org/search`, no key) for brand/name lookup. OFF's own docs say full-text search is not available in API v2/v3, and `/cgi/search.pl` is legacy and "not recommended for new integrations".
- No new API keys, no paid services, no backend or Supabase change, no `ai-proxy` change.
- Barcode "secondary source" = OFF only for now (decision 1: option A). A keyed source such as USDA is deferred and needs a separate approval.

### Research notes (checked 2026-10-22)

| Topic | Finding | Source |
|---|---|---|
| Rate limits | 15 req/min/IP for product reads, 10 req/min/IP for search. Over the limit gives HTTP 503. | [OFF API docs](https://openfoodfacts.github.io/openfoodfacts-server/api/), [intro](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/) |
| Search-as-you-type | Not allowed in practice ("you would be blocked very quickly"). Search only on an explicit user action. | OFF API docs |
| User-Agent | Required, format `AppName/Version (ContactEmail)`. | OFF API docs |
| API usage form | OFF asks apps to fill a short form before use. This is an action for the app owner. | OFF intro |
| Bulk | More than a few hundred products: use the CSV/JSONL export, not the API. | OFF API docs |
| Blocking | OFF reserves the right to IP-ban abusive use. | OFF intro |
| Search-a-licious | `GET /search` with `q` (Lucene syntax), `langs`, `page_size`, `page`, `fields`, `sort_by`, `index_id`. No rate limit is published. | [openapi.json](https://search.openfoodfacts.org/openapi.json) |
| Licence | Database: ODbL. Contents: DbCL. Images: CC BY-SA. Attribution and share-alike apply; data "must not be used for medical purposes"; accuracy is not assured. | [Terms of use](https://world.openfoodfacts.org/terms-of-use) |
| Not verified | Country subdomain behaviour, the exact Search-a-licious field names, and the phrase "1 API call = 1 real scan" (it appeared in a search summary, not in the fetched official page). | |

Consequences: search is user-initiated only, one request at a time, throttled below 10/min (at most one per 6 s), with a result cache. Each phone has its own IP, so the per-IP limit is per user, but shared mobile networks can still trigger 503; that case must degrade gracefully.

### Implementation notes (2026-10-23)

- A real Search-a-licious answer was captured as `test/fixtures/off_search_mountain_dew_india.json`. It showed: `brands` is a **list**; `nutriments` can be missing or null; `quantity` is often junk ("3", "6") or missing, so a size is only read when it has a unit, from `quantity` or from the product name ("Mountain Dew 750 ml").
- Indian Mountain Dew records give 49 kcal, 12.3 g carbs, 0 g protein and 0 g fat per 100 ml. The "Mountain Dew 750 ml" record exists but has **no nutrition**: it is an exact product match with no data, and other sizes are offered, never merged into it.
- A photo's zeros are unknown, not measured: the model's 0 for protein or fat is shown as a dash. Exception: all four numbers given as 0 (water). Verified zeros come only from the database.
- For a packaged product the pack size is never taken from the picture. A size printed on the label is used only to find the product. The amount must be confirmed by the user unless an exact record states its size.
- Exact needs the same brand, name and flavour, an agreeing size, a listing for India, and a single such record. Anything else is "possible" and the user chooses.

### Nutrition data integrity (2026-10-24)

Approved by the owner: Phases 1 to 3 now, a secondary source later and separately.

- **Status of every value.** `NutrientStatus` is derived for each nutrient: unknown (no usable value), known zero (a source says 0), known, or an unchecked AI estimate. `FoodItem.valueOf` / `statusOf` are the one place that decides; `NutrientFormat` is the one way a value is written (`—`, `0.0g`, `12.3g`, `~78.0g`). The core four keep a placeholder number plus the `unknownNutrients` set (a rewrite to nullable fields would touch the 250-food list, every saved entry and most tests); the optional ones (sugar, fibre, sodium, saturated fat, salt) are nullable.
- **Totals.** A day's calories, protein, carbs and fat are exact only when every food gave a value. Otherwise they show a lower bound ("14+g") because an amount cannot be negative, and a dash when no food gave one. This holds on the macro cards, the hero card, the dashboard, meal cards, and the AI coach context (prompt, direct answers and tools).
- **Bases.** Values are per 100 g, per 100 ml, per serving, per package, or unknown. Scaling is `value x amount / reference amount`. Grams are never read as millilitres. A per-serving or per-package value is scaled by weight or volume only when the source states the serving's or package's size in the same kind of unit. Unknown basis keeps the older behaviour on purpose (custom and older foods keep logging).
- **Provenance.** Each food stores its source (Open Food Facts, AI estimate, the user's entry, the built-in list, or unrecorded), a link, how it was matched (barcode, exact product, picked by the user) and when it was retrieved. Finding a record does not make it verified: Open Food Facts is community-contributed and the source note says so.
- **Older data.** Existing entries keep their numbers and are marked "source not recorded"; nothing is relabelled as verified.
- **Barcode in a photo.** A barcode the AI reads is used only if its check digit is right, and the record found must resemble the photo, otherwise it is only offered for choosing.
- **Caching.** Lookups are cached in memory for the session: a match for hours, a choice list for minutes, "nothing found" briefly, a failure never. A search happens only after a photo, never while typing or rebuilding.
- **Not built.** The secondary source (USDA FoodData Central) needs a key, so it must be added server-side only; it is a separate task. Persisting a user's pick, a privacy-policy paragraph about sending the product name to Open Food Facts, and per-package values from Open Food Facts (it gives none) are also open.

### Nutrition consumer audit (2026-10-25)

Every reader of consumed nutrition was traced. The rule: a total that leaves out foods with unknown values is a minimum. It may prove a target was reached; it may never prove intake is low, or give "how much is left". `NutritionTotals` exposes `caloriesComplete` / `proteinComplete` (and carbs, fat), and `proteinRemaining` / `caloriesRemaining` return null when incomplete.

| Consumer | Purpose | Treatment |
|---|---|---|
| Macro cards, hero card, dashboard, meal cards, AI coach prompt and tools | display | Done earlier: "N", "N+", or a dash |
| Recovery engine nutrition score | rule | A shortfall (under-fueling) only on a complete total; a minimum can raise the score; otherwise the neutral score |
| `HealthPredictionEngine` protein feature | ML input | Unknown protein is imputed with a neutral 100 g (a known minimum above that is kept); never 0 |
| `MLFeatureEngineeringService` nutrition adherence | ML feature | Only complete parts are used; none complete gives the neutral 0.88 |
| Insight rules (protein reminder, calorie surplus) | rule | No reminder on unknown protein; a surplus from a minimum reads "at least" |
| Daily coach brief (`DailyCoachBrief`) | rule | Remaining protein/calories are null when unknown; no key suggestion about protein |
| Smart notifications and the athlete coach engines (decision, planner, notifications) | rule | `NutritionStateSummary` carries `proteinComplete` / `caloriesComplete`; no shortfall claims when incomplete |
| Weekly coach and athlete reviews | analytics | Complete days only for averages and rates (`WeeklyNutritionStats`); text says what was left out; the grade drops the protein part instead of scoring 0% |
| `NutritionAnalyticsService` / `NutritionSummary` | analytics | Per-nutrient complete days only; unknown-day counts; totals and weekly bars are minimums (marked "+"); no macro split without a day with all three macros |
| Analytics cards, insights, recommendations, daily brief | display and rules | Dash, "+" and notes; no protein claim without a complete protein day |
| Weight-goal banner | banner | No remaining figure when calories are incomplete; "target reached" still shown when the minimum reaches it |
| History for the weekly views | data | A day whose only foods are unknown is still a logged day |
| XP and achievement rules (`>= target`) | rule | Left as is: they only reward when the minimum already reaches the target |
| Progress bars | display | Fill by the known amount; the label carries the "+" |
| Legacy `getProteinConsumed` | none | No production reader; left alone |
| `ml_inference_service` fallback inputs | demo defaults | Not logged nutrition; left alone |
| Supabase typed-column mappers | dormant | No production callers; live sync stores day JSON, which keeps the unknown sets |

Zero sources for a photo: a bare 0 from the AI is unknown. A zero counts only when the model names the nutrient in `confirmedZero`, and calories cannot be zero beside a non-zero macro. No product or food names are special-cased. A saved result missing a number reads it as unknown. Manual entry rejects text that is not a number. Open Food Facts zeros and user-typed zeros stay known zeros. Old stored barcode products with four zeros and no recorded source stay unknown (a deliberate migration choice).

## 3. Commands

```
flutter analyze --fatal-infos --no-pub
flutter test
flutter test test/unit/<file>.dart
dart format --output=none <files I edited>
graphify update .
```

## 4. Project structure (reuse, do not restructure)

- Models: `lib/models/food_item.dart` (extend additively), `food_scan_result.dart`, `food_analysis_result.dart`.
- OFF: `lib/services/food/openfoodfacts_service.dart` (barcode). New, small files under `lib/services/food/` for the search client and the matcher.
- Repository: `lib/repositories/food_repository.dart`. Scaling: `lib/services/nutrition/nutrition_calculator.dart`.
- UI: `lib/screens/unified_food_scanner_screen.dart`, `lib/widgets/nutrition/scanned_food_result_card.dart`, `food_result_parts.dart` (reuse `SourceBadge`).
- Legacy OFF readers (`food_database_service.dart`, `food_api/remote_food_mapper.dart`) are **not** touched unless a failing regression proves it necessary.

## 5. Code style

Match the surrounding Dart. Pure functions for matching and scaling. Injected `http.Client` (tests use `MockClient`). No new dependencies. Format only files I edit that were clean at HEAD, plus my own new files.

## 6. Testing strategy

- Unit: serialization back-compat (old cached JSON loads unchanged), basis parsing, scaling (including refused conversions), matcher scoring and fixtures, query building, cache rules.
- Service: `MockClient` for timeout, offline, 429/503, malformed JSON, empty and ambiguous results.
- Widget: each label state, dashes for unknowns, 360x640 with a long name, manual entry reachable.
- Regression: existing barcode, photo, unified logging and AI chat tests stay green.
- No live AI calls. At most one read-only OFF request to capture a fixture.
- Widget tests are not device proof. Each checkpoint ends with exact phone steps for the owner.

## 7. Boundaries

Always:
- keep provenance; treat missing as unknown; keep existing keys and behaviour; send the OFF User-Agent.

Ask first:
- any keyed or paid source, Supabase or Edge Function change, `ai-proxy` change, new dependency, change to legacy OFF readers.

Never:
- invent or default nutrition values; present a possible match as exact; auto-accept a fuzzy match; cache ambiguous results as verified; put a key in the app; search as the user types.

## 8. Caching rules

- Automatic exact match: cached as a verified record (existing scanned-food cache).
- User's explicit pick from a candidate list: cached separately and labelled as a user-confirmed match.
- Ambiguous or empty results: never cached as verified; a short-lived negative cache is allowed to avoid repeat requests.

## 9. Decisions

| # | Decision |
|---|---|
| 1 | Improve OFF first. No new keys, paid services or backend changes. |
| 2 | India by default, widen if insufficient. Region is never proof. |
| 3 | Research OFF rules first (done above). |
| 4 | Caching as in section 8. |
| 5 | AI prompt: add brand, variant, pack size, packaged flag only if the response stays backward compatible. No `ai-proxy` change. |
| 6 | Constraints live in `CLAUDE.md`. |
| 7 | Owner verifies the APK on a phone at every checkpoint; steps are provided. |
| 8 | This spec and the tasks are saved in the repo. |

## 10. Open items for the owner

- Fill OFF's API usage form (app owner action).
- Done: the User-Agent is `Atlas/<pubspec version> (lzadeng_be24@thapar.edu)`. A test keeps its version equal to `version:` in `pubspec.yaml`.
