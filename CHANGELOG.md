# Changelog

## Current

### Added
- Phase 2 Migration: Introduced `NotificationRepository` abstraction (`lib/data/notification_repository.dart`) and `NotificationService` (`lib/data/notification_service.dart`).
- Phase 2 Migration: Introduced `AIChatRepository` abstraction (`lib/data/ai_chat_repository.dart`) and `AIChatService` (`lib/data/ai_chat_service.dart`).
- Phase 2 Migration: Introduced `NutritionRepository` abstraction (`lib/data/nutrition_repository.dart`) and `NutritionService` (`lib/data/nutrition_service.dart`).
- Phase 2 Migration: Introduced `WorkoutRepository` abstraction (`lib/data/workout_repository.dart`) and `WorkoutService` (`lib/data/workout_service.dart`).
- Phase 2 Migration: Introduced `ProfileRepository` abstraction (`lib/data/profile_repository.dart`) and `LocalProfileRepository` implementation.
- Created unit safety test suite covering `UserProfile`, `ActiveWorkoutSession`, `LocalStorage`, `ProfileProvider`, `WorkoutRepository`, `NutritionRepository`, `AIChatRepository`, `NotificationRepository`, and workout session restore logic (`test/unit/`).
- Created strongly-typed Dart data models: `UserProfile`, `NotificationModel`, `ChatMessage`, and `ActiveWorkoutSession` in `lib/models/`.
- Added workout identity fields (`workoutName`, `workoutId`) to `ActiveWorkoutSession` to prevent cross-workout session state corruption.

### Changed
- Decoupled `notifications_screen.dart` from direct `LocalStorage` calls by introducing `NotificationService`.
- Decoupled `ai_coach_chat_screen.dart` from direct `LocalStorage` calls for history and AI response processing by introducing `AIChatService`.
- Decoupled `dashboard_screen.dart` from direct `LocalStorage` calls for protein tracking by introducing `NutritionService`.
- Decoupled `workout_session_screen.dart` and `workout_history_screen.dart` from direct `LocalStorage` calls by using `WorkoutService`.
- Decoupled `ProfileProvider` from direct `LocalStorage` dependency by injecting `ProfileRepository`.
- Unified profile creation in `onboarding_screen.dart` to use `ProfileProvider` as the single profile update path.
- Mapped all onboarding fields (DOB, goal, experience, diet, height, weight) directly to canonical `UserProfile` model properties.
- Updated `workout_session_screen.dart` to save and validate active sessions using strongly-typed `ActiveWorkoutSession` identity matching.
- Refactored `LocalStorage` in `lib/data/local_storage.dart` to return and store strongly-typed models instead of untyped `Map<String, dynamic>`.

### Fixed
- Verified 100% test pass rate (25/25 tests passing) across model serialization, legacy key compatibility, repository abstractions, round-trip storage, and workout session restore matching.
- Prepared AI Coach chat architecture for future AI backend integration (such as Gemini API / Firebase AI Logic).
- Prevented active workout session persistence from resuming against unmatched workout definitions.
- Provided migration handling for legacy saved workout sessions lacking workout identity fields.
- Eliminated duplicated age calculation logic in `onboarding_screen.dart` in favor of `ProfileProvider` dynamic age getter.
- Improved data contract consistency across onboarding and profile editing flows.

## Previous Changes
- Initial architecture analysis and baseline Flutter setup.
