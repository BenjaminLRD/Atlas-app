# Phone test: GPS cardio and Community run/ride cards

Automated tests use a scripted GPS source. None of this has been run on a
physical phone. Please check on a real device (arm64 APK):

## Outdoor run / ride
1. Cardio & Activity > "Outdoor Run". Tap Start. Allow location when asked.
   - Deny it once: the amber message appears and Start stays.
   - Deny it permanently: "Settings" opens the app's permission page.
   - With location switched off: "Turn on" opens location settings.
2. Walk or jog outside for a few minutes.
   - The first fix can take 10 to 30 s ("Searching for GPS").
   - Distance, duration, current and average pace rise; the route line grows.
   - Pinch and drag the map.
3. Pause: distance and time stop. Walk a block while paused, resume: the block
   is not added.
4. Enter a building or tunnel: after about 12 s the "GPS signal is weak" strip
   shows, and clears when the signal returns.
5. Finish: summary shows the route, distance, pace, duration, calories (only if
   your profile has a weight; labelled est.). "Save activity" only appears if
   saving failed.
6. Repeat with "Outdoor Ride": speed in km/h, not pace.
7. Discard asks first and saves nothing. Back during a session asks first.

## Known limits to confirm
- Tracking is foreground only: lock the screen or leave the app and Android may
  stop GPS updates. Keep the screen on while recording. (A foreground service
  would be needed for background tracking; not added.)
- Accuracy under trees or between tall buildings is limited by the phone.

## Community
8. After saving, add a caption and "Share to Community". Check the post in the
   feed under "Run & Ride": route preview, distance, duration, pace/speed.
   - Tap the route: the full activity opens. Tap the title: the post page opens.
   - "Hide the first and last 200 m" is ticked by default: the shared route
     should start and end 200 m away from your door.
9. Like, comment and open the athlete's profile from the card.

## Showcase Mode
10. Turn Showcase on: Community > "Run & Ride" shows labelled SAMPLE ACTIVITY
    cards with SAMPLE ROUTE badges; the cardio hub shows "SAMPLE ACTIVITIES
    (DEMO)". Sharing a recorded activity is switched off with a note.

## Added in the finalisation pass (all need a real phone)
- Map: streets, parks and the route show under the line; pinch and drag work; the attribution is visible. Turn on airplane mode and open an activity: you should see the plain route with "Map unavailable" and a Retry.
- Background: start a run, lock the screen for several minutes, walk, unlock. Distance and the route should have kept growing; Android shows a "recording" notification the whole time; the time counts the locked minutes. Switch to another app and back. Finish: the notification disappears. Also try Pause while locked.
- Kill the app mid-run (swipe it away): reopen Cardio & Activity, you should be offered the unfinished run. Check what it recovered.
- iPhone: the blue location indicator shows while recording in the background. iOS background tracking is configured but has never been run on a device.
- Privacy: share with 200 m hidden; open the post as another account. The route must not start or end at your door. Try Don't share a route.
- History: Cardio & Activity > Cardio history; filter; tap into an activity.
- Real backend: run `test/live/cardio_community_live_test.dart` with two throw-away accounts on a staging project (instructions at the top of the file).

## Planned stops and the map look (added; needs a real phone)
- Start a run. Tap "Add stops" at the top left of the map. Tap the map: a numbered stop appears; the last one is the destination (flag). Add 3 stops, drag to reorder, remove one, tap Done: the summary shows the count and straight-line distances.
- Check the stops do not change your recorded route or distance, and that Ride works the same.
- With the screen locked and unlocked again the stops are still there; finishing or discarding the activity clears them.
- Look at the map in dark and light mode: streets, labels and parks must stay readable in dark mode; the route line is emerald; the floating buttons are translucent and do not block panning or pinch-zoom.
- Turn on airplane mode: the plain route shows, "Add my position" still adds a stop.
