# Android release checklist (Google Play)

First release target: Google Play, internal testing track.

## 1. Backend (once per environment)

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set GEMINI_API_KEY=<new key>
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<long random string>
supabase functions deploy ai-proxy
supabase functions deploy delete-account
supabase functions deploy ranked-sync
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

In the Supabase dashboard:
- Authentication → URL configuration: set the site URL / redirect for password
  reset emails (a web page or app link where users set a new password).
- Decide whether email confirmation is required (the app handles both).

## 2. Signing key (once; keep it safe forever)

```bash
keytool -genkey -v -keystore %USERPROFILE%\atlas-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (git ignores it):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=C:\\Users\\<you>\\atlas-upload.jks
```

Use Play App Signing (Play keeps the app signing key; this is the upload key).
Back up the keystore and passwords outside the repository.

## 3. Build

`.env` holds client-safe values only: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`REVENUECAT_ANDROID_KEY`. Never put `GEMINI_API_KEY` in it.

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info --dart-define-from-file=.env
```

Bump `version:` in `pubspec.yaml` (`name+code`) for every upload; the code
must always increase.

## 4. RevenueCat and products

- Play Console → Monetize → Subscriptions: create `atlas_monthly_pro` and
  `atlas_annual_pro` (base plans), and in-app product `atlas_lifetime_pro`.
  Set prices per country (regional pricing) there.
- RevenueCat: add the Play app (service account credentials), import the
  products, create entitlement `pro` with all three, and a current offering
  with their packages.
- RevenueCat → Integrations → Webhooks: URL
  `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`, Authorization
  header `Bearer <REVENUECAT_WEBHOOK_SECRET>`.
- Add license testers in Play Console and test a purchase, a restore on a
  second device, and cancellation.

## 5. Play Console: App content

- **Privacy policy**: publish `PRIVACY_POLICY.md` (fill in the placeholders)
  at a public URL.
- **Account deletion**: the app has Settings → Delete Account. Play also needs
  a web link where users can request deletion without the app (a simple page
  or form that emails you).
- **Data safety** (matches the privacy policy):
  - Collected and stored: email, name, user IDs; fitness info (workouts,
    nutrition, cardio); photos (community posts, meal photos sent for
    analysis); videos (Ranked proof, only when submitted); app interactions
    (likes, comments, reports); purchase history.
  - Health info read from Health Connect: processed on device and not stored
    on our servers, but a daily summary (sleep, heart rate, resting heart
    rate) is sent with AI coach requests to Google's Gemini API, so declare
    health info as shared with a service provider for app functionality.
    Check Health Connect's policy on transfers to AI services before
    submitting; if needed, remove those fields from the coach prompt
    (`lib/services/ai/coach_prompt_builder.dart`).
  - Shared with service providers only (Supabase, Google Gemini API,
    RevenueCat); not sold; encrypted in transit; users can request deletion.
- **Health Connect**: complete the Health permissions declaration for each
  READ permission in `AndroidManifest.xml` (steps, active calories, heart
  rate, resting heart rate, HRV, sleep, weight, body fat, lean body mass),
  with the in-app reason, and link the privacy policy. Only request what the
  app uses.
- **Camera**: used for food/barcode scanning and on-device form analysis.
- **User-generated content**: report and block are in the app, reported
  content is hidden after 3 reports and reviewed in
  `community_review_queue`; publish community guidelines / terms of use
  with zero tolerance for objectionable content, and respond to reports.
- **Content rating** questionnaire, **target audience** (13+), **ads**: none.

## 6. Before promoting beyond internal testing

- Test on real devices: sign up/in, sync across two phones, Health Connect
  permissions and readings, live camera form check (front and back camera),
  Ranked sync and a proof video, purchase/restore, report/block, delete
  account.
- Replace placeholder `aizawlgym.com` URLs/emails in the code with your real
  domain (support email, Sentry if used).
- Rotate the Gemini key if it was ever in a build or in git history.
