# Third-party notices

Atlas includes code adapted from the following open-source project. The
original license text is reproduced as the license requires.

## FitnessPipe

- Source: https://github.com/jinzishuai/fitnessPipe
- Files it informed in Atlas:
  - `lib/ai_form_coach/services/angle_smoother.dart`, adapted from
    `packages/fitness_counter/lib/src/core/smoothing.dart` (angle smoothing
    with an exponential moving average and a warm-up window)
  - `lib/ai_form_coach/services/feedback_throttle.dart`, adapted from
    `packages/fitness_counter/lib/src/form_analyzers/feedback_cooldown_manager.dart`
    (global and per-message feedback cooldowns, with a priority rule)
- Atlas changes: ported to Atlas's own landmark and feedback types; the
  smoothing values, the cooldown values and the rule that form faults bypass
  the cooldown are Atlas's own. No FitnessPipe exercise thresholds are used.

```
MIT License

Copyright (c) 2026 FitnessPipe Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
