# Changelog

## Current

### Added
- Created unit safety test suite covering `UserProfile`, `ActiveWorkoutSession`, `LocalStorage`, `ProfileProvider`, and workout session restore logic (`test/unit/`).
- Created strongly-typed Dart data models: `UserProfile`, `NotificationModel`, `ChatMessage`, and `ActiveWorkoutSession` in `lib/models/`.
- Added workout identity fields (`workoutName`, `workoutId`) to `ActiveWorkoutSession` to prevent cross-workout session state corruption.

### Changed
- Unified profile creation in `onboarding_screen.dart` to use `ProfileProvider` as the single profile update path.
- Mapped all onboarding fields (DOB, goal, experience, diet, height, weight) directly to canonical `UserProfile` model properties.
- Updated `workout_session_screen.dart` to save and validate active sessions using strongly-typed `ActiveWorkoutSession` identity matching.
- Refactored `LocalStorage` in `lib/data/local_storage.dart` to return and store strongly-typed models instead of untyped `Map<String, dynamic>`.
- Updated `ProfileProvider` in `lib/data/profile_provider.dart` to manage internal state using `UserProfile` while preserving external getter interfaces.

### Fixed
- Verified 100% test pass rate across model serialization, legacy key compatibility, round-trip storage, and workout session restore matching.
- Prevented active workout session persistence from resuming against unmatched workout definitions.
- Provided migration handling for legacy saved workout sessions lacking workout identity fields.
- Eliminated duplicated age calculation logic in `onboarding_screen.dart` in favor of `ProfileProvider` dynamic age getter.
- Improved data contract consistency across onboarding and profile editing flows.

## Previous Changes
- Initial architecture analysis and baseline Flutter setup.
