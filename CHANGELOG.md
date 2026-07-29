# Changelog

## Current

### Added
- Created `AppDependencies` manual composition root (`lib/data/app_dependencies.dart`) for zero-package dependency wiring.
- Created in-memory fake repository test suite (`test/unit/fake_repositories_test.dart`) for pure service and provider unit testing.
- Phase 2 Migration: Introduced `NotificationRepository` abstraction (`lib/data/notification_repository.dart`) and `NotificationService` (`lib/data/notification_service.dart`).
- Phase 2 Migration: Introduced `AIChatRepository` abstraction (`lib/data/ai_chat_repository.dart`) and `AIChatService` (`lib/data/ai_chat_service.dart`).
- Phase 2 Migration: Introduced `NutritionRepository` abstraction (`lib/data/nutrition_repository.dart`) and `NutritionService` (`lib/data/nutrition_service.dart`).
- Phase 2 Migration: Introduced `WorkoutRepository` abstraction (`lib/data/workout_repository.dart`) and `WorkoutService` (`lib/data/workout_service.dart`).
- Phase 2 Migration: Introduced `ProfileRepository` abstraction (`lib/data/profile_repository.dart`) and `LocalProfileRepository` implementation.
- Created unit safety test suite covering `UserProfile`, `ActiveWorkoutSession`, `LocalStorage`, `ProfileProvider`, `WorkoutRepository`, `NutritionRepository`, `AIChatRepository`, `NotificationRepository`, and workout session restore logic (`test/unit/`).
- Created strongly-typed Dart data models: `UserProfile`, `NotificationModel`, `ChatMessage`, and `ActiveWorkoutSession` in `lib/models/`.

### Changed
- Converted `NotificationRepository`, `NotificationService`, `AIChatRepository`, and `AIChatService` public contracts to operate exclusively on strongly-typed models (`NotificationModel`, `ChatMessage`), removing duplicate `Map<String, dynamic>` API surfaces.
- Updated workout session restoration logic to perform `workoutId` as the primary identity check, using `workoutName` strictly as a fallback for legacy sessions.
- Cleaned up debug logging statements and improved JSON serialization error handling across `LocalStorage`.
- Decoupled `notifications_screen.dart` from direct `LocalStorage` calls by introducing `NotificationService`.
- Decoupled `ai_coach_chat_screen.dart` from direct `LocalStorage` calls for history and AI response processing by introducing `AIChatService`.
- Decoupled `dashboard_screen.dart` from direct `LocalStorage` calls for protein tracking by introducing `NutritionService`.
- Decoupled `workout_session_screen.dart` and `workout_history_screen.dart` from direct `LocalStorage` calls by using `WorkoutService`.
- Decoupled `ProfileProvider` from direct `LocalStorage` dependency by injecting `ProfileRepository`.

### Fixed
- Verified 100% test pass rate across all 32 unit and widget tests.
- Zero static analysis errors or warnings across entire Flutter project (`flutter analyze`).
- Prepared AI Coach chat architecture for future AI backend integration (such as Gemini API / Firebase AI Logic).
- Prevented active workout session persistence from resuming against unmatched workout definitions.

## Previous Changes
- Initial architecture analysis and baseline Flutter setup.
