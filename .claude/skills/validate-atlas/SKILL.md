---
name: validate-atlas
description: Run Atlas's three validation gates (format check in dry-run mode, flutter analyze --fatal-infos --no-pub, full flutter test --no-pub) and report exact exit codes and test counts. Invoke with /validate-atlas.
disable-model-invocation: true
---

# validate-atlas

Run the Atlas validation gates and report the results exactly. This skill only
checks; it does not change project files.

## Rules

- Work in the Atlas project root (`C:\Users\Lalramdina\Desktop\workou\Atlas`).
- **Never run a formatter that writes.** The format step must use
  `--output=none`. Do not run `dart format` without it, and do not use
  `dart fix`, `--fix` or `--output=write`.
- Never run `flutter pub get`, `dart pub get`, `flutter pub upgrade` or any
  other dependency command. `--no-pub` on the analyzer and the tests keeps them
  from resolving dependencies on their own. Do not edit, stage, commit or push
  anything, and do not change CI, dependencies or application code.
- Run all steps even if an earlier one fails, so the report is complete.
- Capture each command's real exit code; do not infer success from the absence
  of output. Use the form that matches the shell tool you are using (below).
- If a command cannot run (tool missing, package configuration missing,
  timeout, crash), report it as **COULD NOT RUN** with the error. Never report
  it as passed.
- Only say validation passed when all three steps exited 0.

## Step 0: package configuration

`--no-pub` needs the dependency setup that `flutter pub get` already created,
and the format check reads the language version from it. Check first:

- Bash: `test -f .dart_tool/package_config.json && echo PRESENT || echo MISSING`
- PowerShell: `if (Test-Path .dart_tool/package_config.json) { "PRESENT" } else { "MISSING" }`

If it is **MISSING**, do not run `pub get`. Report all three steps as
**COULD NOT RUN (package configuration missing; run `flutter pub get`
yourself)** and stop.

## Steps

Use the Bash form with the Bash tool, and the PowerShell form with the
PowerShell tool. The exit-code echo must be in the same call as the command.

1. **Format check (dry run, same as CI):**

   - Bash: `dart format --output=none --set-exit-if-changed . ; echo "EXIT=$?"`
   - PowerShell: `dart format --output=none --set-exit-if-changed .; "EXIT=$LASTEXITCODE"`

   Exit 0 means formatted. Exit 1 means some files would change; the "Changed
   <path>" lines list them and the last line gives the counts
   ("Formatted N files (M changed)"). Report M and N. Nothing is rewritten.

2. **Analyzer:**

   - Bash: `flutter analyze --fatal-infos --no-pub ; echo "EXIT=$?"`
   - PowerShell: `flutter analyze --fatal-infos --no-pub; "EXIT=$LASTEXITCODE"`

   Report the last line ("No issues found!" or "N issues found.") and the exit
   code. Quote any errors, warnings or infos.

3. **Full test suite** (takes a few minutes; allow up to 10 minutes):

   - Bash: `flutter test --no-pub ; echo "EXIT=$?"`
   - PowerShell: `flutter test --no-pub; "EXIT=$LASTEXITCODE"`

   Read the last progress line, for example `+1687 ~4: All tests passed!` or
   `+1680 ~4 -7: Some tests failed.` In it, `+` is passed, `~` is skipped and
   `-` is failed (a missing `-` part means 0 failed). Report passed, skipped and
   failed counts and the exit code. List the names of failing tests from the
   "Failing tests" section.

## Report

Finish with one table:

| Step | Command | Exit code | Result |
|---|---|---|---|
| Format (dry run) | `dart format --output=none --set-exit-if-changed .` | | files needing format / total |
| Analyzer | `flutter analyze --fatal-infos --no-pub` | | issues |
| Tests | `flutter test --no-pub` | | passed / skipped / failed |

Then one line: **ALL PASSED** only if all three exit codes are 0; otherwise
**FAILED** or **INCOMPLETE** (if a step could not run) naming the steps. If the
user gave a previous baseline for the test counts, compare and state the
difference. Do not offer to reformat files unless asked.
