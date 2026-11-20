# Phone check: exercise thumbnails, set timer, views, YouTube

Automated tests cover the logic and the widgets with a fake clock and a fake
link launcher. They do not prove any of this on a real phone. Check these by
hand on the installed APK.

## Thumbnails
- [ ] Exercise library: every row shows a green figure on a dark background (no photo, no blank tile).
- [ ] Dumbbell Bench Press shows a figure lying on a bench with a dumbbell.
- [ ] Lat Pulldown shows the cable tower and a seated pulling position.
- [ ] Workout overview and the live workout screen show the same picture for the same exercise.
- [ ] Scrolling the library is smooth (the pictures are small bundled files).

## Set timer
- [ ] Press START SET: `SET TIME 00:00` appears and counts up each second.
- [ ] Wait about 30 s: it reads about 00:30.
- [ ] Lock the screen for a minute during a set, unlock: the time includes the minute.
- [ ] Press COMPLETE SET: the timer disappears and the rest timer starts.
- [ ] Finish the workout, open it in history: the sets are saved (duration is stored; no screen shows it yet).
- [ ] Start a set, leave the workout without completing it: that set is not counted as done.

## Side / Front view
- [ ] Barbell Back Squat: "Side View" and "Front View" buttons appear; switching shows the other view and keeps the movement going.
- [ ] Plank, Lateral Raise, Cable Chest Fly: no view buttons.

## Video
- [ ] On Barbell Back Squat tap Video, then WATCH ON YOUTUBE: the YouTube app (or the browser) opens the squat video.
- [ ] Turn on airplane mode and tap it again: the panel says it could not open and offers TRY AGAIN and COPY LINK; no blank player.
- [ ] Football / Basketball / HIIT Circuit: the screen says no video is available.
