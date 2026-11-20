# Phone test: step counter

Install the release APK built after Phase 2 (`build/app/outputs/flutter-apk/app-release.apk`). Automated tests cover the logic with a simulated sensor; only this checklist shows that the real sensor works. Use an Android phone, ideally Android 10 or newer.

## How steps are counted
- Live count: the phone's own step counter (no watch or other app needed). It counts steps since the phone last restarted; Atlas turns that into a count per day.
- Health Connect (optional): if you allow it on the Health screen, its steps for the day are read too. The day shows the larger of the two, never the sum, and the source is named under the number.
- The counter keeps running while Atlas is closed. Atlas credits those steps to the day they happened on, but not steps counted across midnight or a phone restart while Atlas was closed. They are skipped, not guessed.
- The count starts when Atlas first sees the sensor each day ("counting since HH:MM"). Steps taken before that are only included if Health Connect has them.

## 1. Grant the permission
1. Open Atlas. On the Dashboard the Steps card shows `--` and "Tap to allow step counting".
2. Tap the card, then "Allow step counting". Android asks about physical activity: choose Allow.
3. Expected: the number becomes `0` and the line under it says "Phone step counter · counting since HH:MM" (it may say "Waiting for the first reading" for a few seconds; walk a few steps).

## 2. Check that it follows real steps
1. Hold the phone or keep it in a pocket and walk exactly 50 steps, counting them.
2. Expected: the Dashboard card and the Cardio & Activity screen rise by about 50 within a few seconds. A difference of a few steps is normal for a phone step counter; a jump of hundreds or no change is a problem.
3. Open Cardio & Activity: the same number appears, with progress toward the goal.
4. Close Atlas completely, walk 30 steps, open Atlas again. Expected: the total includes them (same day).

## 3. Refusal and recovery
1. Android Settings > Apps > Atlas > Permissions > Physical activity: choose Don't allow. Return to Atlas.
2. Expected: no number, "Allow physical activity..." and the button.
3. Tap "Allow step counting" and refuse in the dialog, twice. After the second refusal Android stops asking: Atlas should say so and show "Open app settings".
4. Turn the permission on in settings and return to Atlas. Expected: counting resumes without restarting the app.

## 4. No step sensor
Some phones have no step counter. Expected: "This phone has no step counter" and `--`, never `0`. Health Connect steps still appear if allowed.

## 5. Health Connect and double counting
1. Allow Health Connect on the Health screen (Sync). If a watch or another app writes steps there, compare.
2. Expected: the day shows one number (the larger source), and the line shows the other source. The number is never the sum.

## 6. Day change
1. After midnight, open Atlas. Expected: today starts at `0` counted from the first reading of the new day (or from midnight if Atlas stayed open), and yesterday keeps its own count in the weekly chart on the Health screen.

## What to report
The phone model and Android version, which step above failed, the number Atlas showed against your own count, and whether the Steps card said anything unexpected. I cannot see the phone; none of this is verified until you run it.

## 7. Added after the over-counting review (needs a real phone)
Automated tests use a scripted sensor. To check the real device:
1. Health screen, Data sources card: the line "Today's steps: phone sensor N · Health Connect M" shows both sources. The larger one is the day's number. Walk exactly 100 steps and note both numbers before and after: the phone number should rise by about 100. If only the Health Connect number is far above your own count, the extra steps come from Health Connect (another app or a watch writing steps there), not from Atlas's sensor count.
2. Lock the phone and walk 100 steps, then unlock: the phone number should have risen once by about 100, not twice.
3. Open and close Atlas five times in a row without walking: the number must not move.
4. Restart the phone, walk 100 steps, open Atlas: the day should show those steps once. (Steps counted since the restart are credited after the new, lower counter has persisted for 30 seconds.)
Please report the phone model, Android version, and the two numbers in the Data sources line.
