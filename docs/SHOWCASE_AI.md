# Showcase AI

Showcase Mode lets someone try Atlas AI with no account. This file lists every AI entry point and how each one behaves in Showcase.

## AI entry points

| Feature | Where | Uses the live model in Showcase? |
| --- | --- | --- |
| Atlas AI chat and its quick prompts ("Plan my day", "Analyze my nutrition") | `AICoachScreen` -> `CoachChatService` -> `GeminiAIProvider` | Yes, once the server is updated (see below). The prompt is built from the sample athlete's data. |
| Food photo scan and label reading | `UnifiedFoodScannerScreen` -> `FoodAIVisionService` | Yes. Values stay labelled as AI estimates; unknown nutrients stay unknown. |
| Equipment scan and "explain this machine" | `MachineScannerScreen` -> `MachineScanService` | Yes. |
| Barcode scan, manual food entry | scanner / food search | Not AI. Unchanged. Barcode lookups use the public Open Food Facts database. |
| Daily brief, recommendations, workout plans, recovery and readiness insights | `FitnessProvider` engines | Not model calls. They are local engines that already run on the sample data in Showcase. |
| Chat actions (`AIAgent`) | `CoachChatService.sendAgentMessage` | Not reachable from any screen today. |

Every model call goes through one function, `postGenerateContent`, so all three live features share the same Showcase path.

## How a Showcase request works

- With Showcase Mode on, `AIConfig.usesShowcaseProxy` is true. The request carries the project's public anon key and the `x-atlas-showcase: 1` header, and the body has `showcase: true`.
- It never carries a user token or a user id, even when someone is signed in on the same device.
- The `ai-proxy` function answers it in `handleShowcase`: it is off unless the secret `SHOWCASE_AI_ENABLED=true` is set, requires the anon key, only allows the `coach` and `food_scan` features, caps the body and output size, and applies per-client and global limits.
- The limits are in the memory of the running function instance. They are a best-effort guard, not a durable quota. A durable limit needs a table, which means a migration.

## Isolation

- The chat is stored under its own key in Showcase and is cleared when Showcase starts or ends. The real conversation is never read or written.
- Foods logged from a scan or search in Showcase go to an in-memory log. They add to the demo day's totals, award no XP, and are dropped when Showcase starts or ends.
- Scanned barcode products are not saved to the real scanned-foods list in Showcase.

## What the server needs (not applied automatically)

1. Deploy the updated function: `supabase functions deploy ai-proxy`.
2. Enable it: `supabase secrets set SHOWCASE_AI_ENABLED=true`.

Until then, Showcase AI shows "Showcase AI is not enabled on the server yet." It never shows a sign-in message and never shows a made-up answer.
