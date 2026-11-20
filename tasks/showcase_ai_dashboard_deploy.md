# Showcase AI: Dashboard deployment (prepared, NOT deployed)

Nothing here has been deployed. The production `ai-proxy` function and every
secret are untouched. The Gemini key was not read, printed, rotated or changed.
This machine has no Supabase CLI and no Deno, and no Dashboard session, so the
deployed function and its secrets could not be inspected from here.

## What changes

`supabase/functions/ai-proxy/index.ts` is the complete replacement (single file,
no local imports, pastes into the Dashboard editor as is).

The signed-in path (token check, tier lookup, `consume_ai_quota`, Gemini call)
and everything after the Showcase block are byte-for-byte what is in git. The
change is the Showcase branch only, which runs only when the request carries
`x-atlas-showcase: 1`. Without that header behaviour is identical to today.

Showcase branch, all enforced on the server:
- off unless the secret `SHOWCASE_AI_ENABLED` equals `true`
- bearer must equal this project's anon key
- features `coach` and `food_scan` only; model `gemini-2.5-flash` only
- **the request is rebuilt, not forwarded.** Only a server-fixed system
  instruction, the validated `contents`, and a server-built `generationConfig`
  reach Gemini. Dropped: `tools`, `safetySettings`, `thinkingConfig`,
  `candidateCount` and every other generation field. Allowed from the client:
  `temperature` (clamped 0 to 1), a `maxOutputTokens` at or below 2048, and a
  JSON/plain response type. The server sets the thinking budget (512).
- fixed system instruction: the Atlas chat rules (a verbatim copy of the app's,
  guarded by a test) for chat, a short analysis rule set for the photo scanners.
  The app's note about earlier turns is kept as plain conversation context, never
  as an instruction.
- validation, rejected with 400: unknown fields, roles other than user/model,
  function calls, file parts, more than 12 turns or 4 parts per turn, an image
  that is not jpeg/png/webp or not base64, more than one image, text parts over
  20,000 characters, total text over 32,000 characters, a note over 1,500 chars.
- size: 64 KB for a text-only request; 1.25 MB when it carries one photo.
- per client 30 coach / 8 food-scan per 10 min; global 400 per 10 min (in-memory
  per function instance, so best effort, not a durable quota)
- no user id, no `profiles` read, no quota-table write; uses the existing
  `GEMINI_API_KEY` secret.

Effect on the app: the tool-calling chat path still works in Showcase, but since
`tools` is dropped Gemini answers in plain text and cannot call account tools
(Showcase uses sample data, so nothing is lost). Normal signed-in chat keeps its
tools.

### Testing that was done
- `node --test tool/ai_proxy_local_test/run.mjs` runs the real function source
  with stubs (17 cases: valid coach, food scan, machine scan, oversize, long
  text, malformed contents, config injection, system-instruction override,
  feature flag, rate limits, signed-in authentication). It is Node, not the
  Supabase/Deno runtime, and uses a fake Gemini and a fake auth client.
- `test/unit/showcase_proxy_contract_test.dart` builds the requests the app
  really sends (long chat, chat with photo, tool-calling chat, food scan, machine
  scan) and checks they fit the limits read from `index.ts`.
- Not tested here: the Deno runtime, the gateway's Verify JWT, the real Gemini
  API, secrets, multiple instances. Use `tool/test_showcase_ai.ps1` after deploy.

## Which key the function accepts (updated)

The Showcase branch compares the request's bearer with the project's public
keys, from any of: `SUPABASE_ANON_KEY` (legacy, injected), `SUPABASE_PUBLISHABLE_KEYS`
(new, injected JSON dictionary) and an optional secret you add,
`SHOWCASE_PUBLIC_KEYS` (comma separated). Secret and service-role keys are never
accepted. If none is configured the function answers 503 "no project public key
configured"; a key that does not match answers 401 "Sign in to use Atlas AI."

If `tool/test_showcase_ai.ps1` case 1 returns 401 after deploying this version,
add the Dashboard secret `SHOWCASE_PUBLIC_KEYS` with the value of
`SUPABASE_ANON_KEY` from your local `.env` (the same key the app ships; it is a
public key). Do not paste it into chat. No redeploy is needed; rerun the script.

## Step 0: check the existing Gemini secret without revealing it

1. Supabase Dashboard, your Atlas project, **Edge Functions**, **Secrets** (or
   Project Settings, Edge Functions, Secrets).
2. Look for the name `GEMINI_API_KEY` in the list. The Dashboard shows only the
   name and a hashed digest, never the value. If the name is there, leave it alone.
3. Do not click Edit or Delete on it, and do not "Add new" with the same name:
   saving a new value overwrites the existing one.

(`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically and do not appear as secrets you need to add.)

## Step 1: back up the live function

Edge Functions, `ai-proxy`, Code. Select all and copy the current code into a
local file such as `ai-proxy.live-backup.ts`. This is your one-click rollback.

## Step 2: deploy the replacement

1. In the same editor, replace the code with the contents of
   `supabase/functions/ai-proxy/index.ts`.
2. Leave **Verify JWT** on. The Showcase request sends the project anon key as
   its bearer, and the anon key is a JWT (it starts with `eyJ`), so the gateway
   accepts it. If the project ever moves to the new `sb_publishable_` keys, which
   are not JWTs, turn Verify JWT off for this function; the function then
   checks the key itself.
3. Click **Deploy**.

## Step 3: turn Showcase on

Edge Functions, Secrets, **Add new secret**:
- Name: `SHOWCASE_AI_ENABLED`
- Value: `true`

This adds one secret. It does not touch `GEMINI_API_KEY`. To switch Showcase AI
off at any time, delete or change only this secret.

## Step 4: verify, from this machine

```powershell
powershell -NoProfile -File tool/test_showcase_ai.ps1
```

It prints status codes and the first words of the reply, never the key or URL.
Expected:

| # | Case | Expect |
|---|------|--------|
| 1 | showcase coach request | 200 and a short Gemini reply |
| 2 | wrong bearer | 401 |
| 3 | disallowed model | 400 |
| 4 | anon key with no showcase header (signed-in path) | 401, "session expired" |
| 5 | unsupported role | 400 |
| 6 | 70,000-character message | 400 |
| 7 | injected `tools` / `safetySettings` / `candidateCount` | 200, extras ignored |

Cases 1 and 7 each make one tiny Gemini call. Case 4 proves the signed-in path still
refuses a non-user token. Then confirm signed-in AI on a phone or the app with a
real account (it was not changed, but it is the path to re-check).

## If something is off

| Symptom | Meaning | Fix |
|---|---|---|
| 503 "Showcase AI is not enabled" | secret missing or not exactly `true` | add `SHOWCASE_AI_ENABLED=true`, redeploy not needed |
| 503 "not configured on the server" | `GEMINI_API_KEY` secret missing | check Step 0; do not paste a new key here unless it is truly missing |
| 401 on case 1 | bearer is not this project's anon key, or old code still deployed | confirm the new code deployed |
| 429 | rate limit | wait 10 minutes |
| signed-in AI broken | unexpected | restore `ai-proxy.live-backup.ts` from Step 1 |

## Rollback
Paste the backup from Step 1 and deploy, and/or delete the `SHOWCASE_AI_ENABLED`
secret (that alone disables the Showcase branch immediately).

## App side
The release APK needs no change: it already contains the Showcase client. After
Step 4 passes, install the arm64 APK, turn on Showcase Mode, and ask Atlas AI a
question (a reply means the whole pipeline works).
