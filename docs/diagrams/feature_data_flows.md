# Feature data flows

How the main features move data, taken from the source code. Class names are real; see the file list at the end.

## Steps, GPS and health data

```mermaid
flowchart LR
  subgraph Sources["Sources on the phone"]
    PED["Phone step counter<br/>(pedometer, cumulative since boot)"]
    HCS["Health Connect<br/>(steps, sleep, heart rate, ...)"]
    GPSS["GPS fixes<br/>(geolocator, foreground service)"]
  end

  PED --> LED["StepLedger<br/>per-day totals from counter differences,<br/>reset held 30 s before accepted"]
  HCS --> LED
  LED --> DAY["Day total = larger of phone and Health Connect<br/>(never their sum)"]
  DAY --> SCN["StepCounterService<br/>(ChangeNotifier)"]
  SCN --> UI1["Steps and Health screens"]
  HCS --> HSY["Health sync and recovery services"] --> UI1

  GPSS --> TRK["CardioTracker<br/>rejects accuracy worse than 30 m<br/>and impossible speed jumps<br/>TrackerState: idle, running, paused, finished, discarded"]
  TRK --> RES["CardioResult<br/>distance, time, route, estimated calories"]
  RES --> JNL["Cardio journal<br/>(local storage, then cloud sync)"]
  RES --> PRV["RoutePrivacy<br/>hide 200 m, hide 500 m, full, none"]
  PRV --> PUB["CardioPostPublisher -> Community post"]
```

## Nutrition

```mermaid
flowchart TD
  BC["Barcode (mobile_scanner)"] --> GT["Normalise GTIN"] --> OFFQ["Open Food Facts lookup"] --> MT["ProductMatcher<br/>exact / choose / none"]
  PH["Photo"] --> AIV["AI food scan<br/>(ai-proxy -> Gemini)"] --> EST["Estimate, nutrients may be null"]
  MAN["Manual entry or catalogue"] --> FI
  MT --> FI["FoodItem<br/>basis, source, set of unknown nutrients"]
  EST --> FI
  FI --> POR["Portion and unit (PortionUnit)"]
  POR --> TOT["Totals add only known values<br/>result marked partial if any is missing"]
  TOT --> LOG["Nutrition log for the day<br/>(local storage, cloud sync)"]
  TOT --> MP["Meal preps, recipes, custom meals"]
  LOG --> UI2["Diet Plan screen: calories and macros"]
```

## Local storage and cloud synchronisation

```mermaid
flowchart LR
  UI["Screens"] --> PV["Providers (FitnessProvider, ProfileProvider)"]
  PV --> LR["Local repositories<br/>(SharedPreferences)"]
  PV --> CR["Cloud repositories"]
  CR --> Q["Pending-write queue<br/>(upsert or delete per table)"]
  Q --> SBDB[("Supabase tables under RLS")]
  AUTHS["Supabase session<br/>(secure storage)"] --> CR
  SHW["Showcase Mode"] -. "separate storage keys,<br/>never writes real records" .-> LR
```

## Where this is implemented

| Flow | Main files |
|---|---|
| Steps | `lib/services/steps/step_ledger.dart`, `step_counter_service.dart` |
| GPS cardio | `lib/services/cardio/cardio_tracker.dart`, `route_privacy.dart`, `lib/services/community/cardio_post_publisher.dart` |
| Health Connect | `lib/services/health/` |
| Barcode and food data | `lib/services/food/` (`openfoodfacts_service.dart`, `product_lookup_service.dart`, `product_matcher.dart`) |
| Nutrition models | `lib/models/food_item.dart`, `meal_prep.dart`, `recipe.dart` |
| Local and cloud storage | `lib/data/local/`, `lib/services/cloud/` |
| Showcase Mode | `lib/providers/showcase_mode_provider.dart`, `lib/services/showcase_mode_service.dart` |
