# AI request flows

Atlas does **not** train a model. It uses Google's hosted Gemini model `gemini-2.5-flash`, and only the `ai-proxy` Edge Function calls it. The application sends `{model, feature, request}` to the proxy, where `feature` is `coach` or `food_scan`.

## 1. AI Coach, signed-in user

```mermaid
sequenceDiagram
  autonumber
  actor U as Athlete
  participant App as Flutter app (GeminiAIProvider)
  participant P as ai-proxy
  participant A as Supabase Auth and DB
  participant G as Gemini API

  U->>App: question (optional photo)
  App->>App: build prompt: rules, last 8 turns, profile context
  App->>P: POST with the user's access token
  P->>A: auth.getUser(token)
  A-->>P: user (or 401)
  P->>A: consume_ai_quota(user, feature, daily limit)
  A-->>P: allowed or limit reached (429)
  P->>G: generateContent (server-side key)
  G-->>P: candidates
  P-->>App: response unchanged
  App->>App: accept only if 200, complete, not blocked
  App-->>U: answer, or a clear error message
```

Daily limits (counted per user and feature): coach 10 for the free tier and 400 for the pro tier; food scan 3 and 100.

## 2. Showcase Mode (no account)

```mermaid
sequenceDiagram
  autonumber
  actor V as Visitor
  participant App as Flutter app
  participant P as ai-proxy (Showcase branch)
  participant G as Gemini API

  V->>App: question or photo
  App->>P: POST with the project public key and header x-atlas-showcase: 1 (no user token)
  P->>P: flag SHOWCASE_AI_ENABLED is true?
  P->>P: bearer equals a project public key?
  P->>P: validate and rebuild the request
  P->>P: per-client and global rate limit
  P->>G: generateContent with a fixed system instruction
  G-->>P: candidates
  P-->>App: response
  App-->>V: answer, or a clear error message
```

What the Showcase branch enforces: only the features `coach` and `food_scan` and the model `gemini-2.5-flash`; roles limited to `user` and `model`; no function calls or file parts; at most 12 turns, 32,000 characters of text and one image; 64 KB for text-only requests and 1.25 MB with a photo; output capped at 2,048 tokens. Anything the client sends for tools, safety settings, thinking configuration or candidate count is dropped, and the system instruction is fixed on the server. Limits: 30 coach and 8 food-scan requests per client per 10 minutes, and 400 requests globally per 10 minutes (kept in memory per function instance, so a best-effort guard rather than a durable quota). The Showcase branch reads no user data and writes none.

## 3. AI food scan

```mermaid
flowchart TD
  A["Take or pick a photo<br/>(max 1280 px, JPEG 85)"] --> B["FoodAIVisionService builds the prompt<br/>asks for JSON, null for unknown values"]
  B --> C{"Showcase Mode?"}
  C -- "yes" --> D["Showcase pathway<br/>public key + header"]
  C -- "no" --> E["Signed-in pathway<br/>user token, food_scan quota"]
  D --> F["ai-proxy -> Gemini"]
  E --> F
  F --> G{"HTTP 200 and parseable?"}
  G -- "no" --> H["Clear error: no food detected, too large, busy, sign in"]
  G -- "yes" --> I["Result labelled as an AI estimate"]
  I --> J["Unknown nutrients stay unknown<br/>(zero only if confirmed)"]
  J --> K["User reviews, then logs (not in Showcase Mode)"]
```

The machine scanner (gym equipment identification) uses the same pathway with the `coach` feature and a catalogue of equipment identifiers.

## Where this is implemented

| Part | File |
|---|---|
| Pathway selection and request building | `lib/services/ai/ai_config.dart`, `lib/services/ai/gemini_transport.dart` |
| Coach provider, answer checks, error messages | `lib/services/ai/gemini_ai_provider.dart` |
| Prompt and safety rules | `lib/services/ai/coach_prompt_builder.dart`, `lib/services/ai/coach_safety_rules.dart` |
| Scanners | `lib/services/food/food_ai_vision_service.dart`, `lib/services/machine/machine_scan_service.dart` |
| Proxy | `supabase/functions/ai-proxy/index.ts` |
