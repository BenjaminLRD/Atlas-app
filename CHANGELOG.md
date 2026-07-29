# Changelog

## Current

### Added
- Phase 3 UI/UX Polish: Dual-Theme Design System in `lib/app_theme.dart` with Apple-inspired light charcoal & translucent dark modes (`AppTheme.lightTheme` & `AppTheme.darkTheme`).
- Created `AppThemeContext` extension on `BuildContext` (`context.appBackground`, `context.appSurface`, `context.appTextPrimary`, `context.appPrimary`, `context.appCardBg`) for automatic light/dark theme adaptability.
- Redesigned core widgets in `lib/widgets/common/`: `AppCard`, `ProgressRing`, `PrimaryButton`, `MetricCard`, and `SectionHeader`.
- Implemented `DietPlanScreen` (`lib/screens/diet_plan_screen.dart`), redesigned `DashboardScreen`, `OnboardingScreen`, and `WorkoutSessionScreen`.
- Created in-memory fake repository test suite (`test/unit/fake_repositories_test.dart`) for pure service and provider unit testing.
- Phase 2 Migration: Introduced `NotificationRepository` abstraction (`lib/data/notification_repository.dart`) and `NotificationService` (`lib/data/notification_service.dart`).
- Phase 2 Migration: Introduced `AIChatRepository` abstraction (`lib/data/ai_chat_repository.dart`) and `AIChatService` (`lib/data/ai_chat_service.dart`).
- Phase 2 Migration: Introduced `NutritionRepository` abstraction (`lib/data/nutrition_repository.dart`) and `NutritionService` (`lib/data/nutrition_service.dart`).
- Phase 2 Migration: Introduced `WorkoutRepository` abstraction (`lib/data/workout_repository.dart`) and `WorkoutService` (`lib/data/workout_service.dart`).
- Phase 2 Migration: Introduced `ProfileRepository` abstraction (`lib/data/profile_repository.dart`) and `LocalProfileRepository` implementation.
- Created unit safety test suite covering `UserProfile`, `ActiveWorkoutSession`, `LocalStorage`, `ProfileProvider`, `WorkoutRepository`, `NutritionRepository`, `AIChatRepository`, `NotificationRepository`, and workout session restore logic (`test/unit/`).
- Created strongly-typed Dart data models: `UserProfile`, `NotificationModel`, `ChatMessage`, and `ActiveWorkoutSession` in `lib/models/`.

### Changed
- Completed dependency wiring cleanup: Audited `main.dart`, top app bar, and all screens (`dashboard_screen`, `workout_session_screen`, `workout_history_screen`, `notifications_screen`, `ai_coach_chat_screen`, `profile_screen`, `onboarding_screen`, `edit_profile_screen`), replacing direct construction with injected instances from `AppDependencies.instance`.
- Converted `NotificationRepository`, `NotificationService`, `AIChatRepository`, and `AIChatService` public contracts to operate exclusively on strongly-typed models (`NotificationModel`, `ChatMessage`), removing duplicate `Map<String, dynamic>` API surfaces.
- Updated workout session restoration logic to perform `workoutId` as the primary identity check, using `workoutName` strictly as a fallback for legacy sessions.
- Cleaned up debug logging statements and improved JSON serialization error handling across `LocalStorage`.

### Fixed
- Verified 100% test pass rate across all 32 unit and widget tests (`flutter test`).
- Zero static analysis errors or warnings across entire Flutter project (`flutter analyze`).
- Prepared AI Coach chat architecture for future AI backend integration (such as Gemini API / Firebase AI Logic).
- Prevented active workout session persistence from resuming against unmatched workout definitions.

## Previous Changes
- Initial architecture analysis and baseline Flutter setup.
