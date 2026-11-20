# System architecture

Atlas is an Android application written in Flutter. It keeps most state on the phone and uses a Supabase project for accounts, synchronised records and one server-side function that is the only component allowed to call the Gemini AI service.

```mermaid
flowchart LR
  subgraph Phone["Android phone: Atlas app (Flutter / Dart)"]
    UI["Screens and widgets<br/>(59 screens)"]
    ST["State holders<br/>(ChangeNotifier providers)"]
    SV["Domain services<br/>training, cardio, steps, nutrition,<br/>hydration, recovery, AI client"]
    LS["Local storage<br/>SharedPreferences + secure storage"]
    SH["Showcase layer<br/>sample data, separate storage keys"]
    UI --> ST --> SV
    SV --> LS
    UI --> SH
  end

  subgraph Device["Phone sensors and platform"]
    GPS["GPS (geolocator)"]
    PED["Step counter (pedometer)"]
    HC["Health Connect (health)"]
    CAM["Camera (mobile_scanner, image_picker)"]
  end

  subgraph SB["Supabase project"]
    AUTH["Auth<br/>(email and password)"]
    DB[("PostgreSQL + RLS<br/>14 tables")]
    STO["Storage buckets"]
    subgraph FN["Edge Functions (Deno)"]
      AIP["ai-proxy"]
      DEL["delete-account"]
      RNK["ranked-sync"]
      RCW["revenuecat-webhook"]
    end
  end

  GEM["Google Gemini API<br/>gemini-2.5-flash"]
  OFF["Open Food Facts"]
  OSM["OpenStreetMap tiles"]
  RC["RevenueCat"]

  Device --> SV
  SV -- "HTTPS, user token" --> AUTH
  SV -- "HTTPS, row access under RLS" --> DB
  SV --> STO
  SV -- "AI requests" --> AIP
  SV --> DEL
  SV --> RNK
  AIP -- "server-side key" --> GEM
  AIP --> DB
  DEL --> DB
  DEL --> STO
  RNK --> DB
  RCW --> DB
  RC --> RCW
  SV -- "barcode lookup" --> OFF
  UI -- "map tiles" --> OSM
```

**How to read it.** The left block is the application. The Gemini key exists only as a Supabase secret, so the application never holds an AI key. The subscription tier in the database is written only by the RevenueCat webhook.

**Source of the components.** Edge Functions: `supabase/functions/`. Tables: `supabase/migrations/`. Plugins: `pubspec.yaml`. Layers: `lib/` (see [flutter_module_dependencies.md](flutter_module_dependencies.md) for the dependency counts measured with Graphify).
