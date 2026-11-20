# Atlas — Privacy Policy

**Effective date**: [DATE]
**Applies to**: the Atlas app for Android and iOS
**Contact**: [privacy@your-domain] · [postal address]

This policy explains what Atlas collects, why, where it goes, and how you
control it. Placeholders in [brackets] must be filled in before publishing.

---

## 1. What we collect

### Your account
- Email address and password. Passwords are handled by our authentication
  provider (Supabase Auth) and stored only as a secure hash.
- Display name and the profile details you enter: age or date of birth,
  gender, height, weight, goals, experience level and preferences.

### What you log in the app
- Workouts (exercises, sets, reps, weights), workout history and personal
  records.
- Meals, calories and macros, nutrition goals.
- Cardio sessions (activity, duration, distance).

When you are signed in, this data is stored in our cloud database so it is
backed up and available on your other devices.

### Health data (Apple Health / Health Connect)
With your permission, Atlas **reads** steps, active calories, heart rate,
resting heart rate, heart rate variability, sleep, weight, body fat and lean
body mass written by your phone, watch, ring or scale.

- Health data is used **only** to show your dashboards, recovery score and
  body composition, and to personalise the AI coach. It is processed on your
  device and is **not stored on our servers**.
- When you message the AI coach, a short summary of today's readings (for
  example sleep duration, heart rate and resting heart rate) is included in
  that request so the advice fits your recovery (see section 3). Our server
  passes it on without storing it.
- Health data is never sold, shared with advertisers, or used for advertising
  or credit decisions.
- Atlas does not write to Apple Health or Health Connect.
- You can turn access off at any time in Health Connect or the Health app.

### Camera, photos and video
- **Barcode scanning** and **exercise form analysis** run entirely on your
  device. Live camera frames and form-check videos are not uploaded.
- **Meal photos** you choose to analyse are sent through our server to an AI
  service (see section 3) to estimate the food and nutrition.
- **Community photos** you post are uploaded and visible to other signed-in
  users.
- **Ranked proof videos** you submit are uploaded to private storage and
  viewed only by our moderators to verify the lift.

### Community and Ranked
- Posts, photos and comments you publish, likes, and the people you block.
- Reports you file about content.
- Your Ranked rank and display name are visible to other signed-in users on
  the leaderboard and next to your posts.

### Purchases
Subscriptions are processed by Google Play or the App Store. We never see your
card or payment details. Our subscription provider (RevenueCat) receives your
purchase status and your account identifier so we can unlock Atlas Pro.

---

## 2. How we use it

- To provide the app: training plans, nutrition targets, recovery insights,
  the AI coach, Ranked mode and the community.
- To keep your data in sync and backed up when you are signed in.
- To enforce fair use (daily AI limits) and to moderate reported content.

We do **not** sell your personal data, and we do not use it for advertising.

---

## 3. Who processes it for us

| Provider | Purpose | Data |
|:---|:---|:---|
| Supabase | Accounts, database, file storage, server functions | Account, logged data, community content, proof videos |
| Google (Gemini API) | AI coach replies and meal photo analysis | Your messages, relevant training, nutrition and recovery context (including today's sleep and heart rate summary), meal photos you analyse |
| RevenueCat | Subscription status | Account identifier, purchase records |
| Google Play / Apple App Store | Payments | Handled under their own privacy policies |
| Open Food Facts | Barcode product lookup | The barcode number only |

AI requests go through our own server, which removes our API key from the app
and limits usage; the content you send is processed by Google under its API
terms.

---

## 4. Security

- Data is encrypted in transit (HTTPS).
- Database access rules (Row Level Security) let each account read and change
  only its own private data. Blocked users cannot see each other's posts.
- On your device, session tokens and sensitive values are kept in Android
  Keystore / Apple Keychain.

---

## 5. Your choices and rights

- **Edit** your profile and logs in the app at any time.
- **Delete your account**: Settings → Delete Account permanently deletes your
  account and all data stored in our cloud (logs, posts, comments, ranks, proof
  videos). You can also request deletion at [deletion page URL] or by email.
- **Health and camera permissions** can be revoked in your device settings.
- Depending on where you live, you may have rights to access, correct, export
  or delete your data, and to complain to a data protection authority. Contact
  us to exercise them.

---

## 6. Retention

We keep your data while your account exists. When you delete your account,
cloud data is deleted promptly; backups expire within [30] days. Data kept only
on your device is removed when you uninstall the app or clear its data.

---

## 7. Children

Atlas is not intended for children under 13 (or the minimum age in your
country). We do not knowingly collect data from them.

---

## 8. Changes

We will update this page and the effective date when this policy changes, and
tell you in the app about significant changes.
