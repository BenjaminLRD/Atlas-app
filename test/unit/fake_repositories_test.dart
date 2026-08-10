import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/data/profile_repository.dart';
import 'package:aizawl_gym/data/workout_repository.dart';
import 'package:aizawl_gym/data/nutrition_repository.dart';
import 'package:aizawl_gym/data/ai_chat_repository.dart';
import 'package:aizawl_gym/data/notification_repository.dart';
import 'package:aizawl_gym/data/profile_provider.dart';
import 'package:aizawl_gym/data/workout_service.dart';
import 'package:aizawl_gym/data/nutrition_service.dart';
import 'package:aizawl_gym/data/ai_chat_service.dart';
import 'package:aizawl_gym/data/notification_service.dart';
import 'package:aizawl_gym/data/app_dependencies.dart';
import 'package:aizawl_gym/models/user_profile.dart';
import 'package:aizawl_gym/models/active_workout_session.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/models/daily_nutrition.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/macro_target.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_log.dart';
import 'package:aizawl_gym/models/chat_message.dart';
import 'package:aizawl_gym/models/notification_model.dart';

/// Fake In-Memory Repositories for Unit Testing without LocalStorage
class FakeProfileRepository implements ProfileRepository {
  UserProfile _profile = UserProfile.defaultProfile();

  @override
  UserProfile getProfile() => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> updateField(String key, dynamic value) async {
    _profile[key] = value;
  }
}

class FakeWorkoutRepository implements WorkoutRepository {
  ActiveWorkoutSession? _activeSession;
  final List<WorkoutHistory> _history = [];

  @override
  ActiveWorkoutSession? getActiveSession() => _activeSession;

  @override
  Future<void> saveActiveSession(ActiveWorkoutSession session) async {
    _activeSession = session;
  }

  @override
  Future<void> clearActiveSession() async {
    _activeSession = null;
  }

  @override
  List<WorkoutHistory> getWorkoutHistory() => List.from(_history);

  @override
  Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    _history.add(entry);
  }
}

class FakeNutritionRepository implements NutritionRepository {
  double _consumed = 0.0;
  double _goal = 140.0;
  MacroTarget _macroTarget = MacroTarget.defaultTarget();
  final Map<String, DailyNutrition> _store = {};

  @override
  double getProteinConsumed() => _consumed;

  @override
  double getProteinGoal() => _goal;

  @override
  Future<void> saveProteinConsumed(double value) async {
    _consumed = value;
  }

  @override
  Future<void> saveProteinGoal(double value) async {
    _goal = value;
  }

  @override
  DailyNutrition getDailyNutrition(String date) {
    return _store[date] ?? DailyNutrition.defaultForDate(date, _macroTarget);
  }

  @override
  Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    _store[dailyNutrition.date] = dailyNutrition;
    _consumed = dailyNutrition.totalProteinConsumed;
  }

  @override
  MacroTarget getMacroTarget() => _macroTarget;

  @override
  Future<void> saveMacroTarget(MacroTarget target) async {
    _macroTarget = target;
    _goal = target.proteinGrams;
  }

  @override
  Future<void> logFoodItem({
    required String date,
    required MealCategory category,
    required FoodItem foodItem,
  }) async {
    final daily = getDailyNutrition(date);
    final updatedMeals = daily.meals.map((meal) {
      if (meal.category == category) {
        final newItems = List<FoodItem>.from(meal.items)..add(foodItem);
        return meal.copyWith(items: newItems);
      }
      return meal;
    }).toList();

    await saveDailyNutrition(daily.copyWith(meals: updatedMeals));
  }

  @override
  Future<void> toggleMealCompletion({
    required String date,
    required String mealId,
  }) async {
    final daily = getDailyNutrition(date);
    final updatedMeals = daily.meals.map((meal) {
      if (meal.id == mealId) {
        return meal.copyWith(isCompleted: !meal.isCompleted);
      }
      return meal;
    }).toList();

    await saveDailyNutrition(daily.copyWith(meals: updatedMeals));
  }

  @override
  Future<void> saveNutritionLog(NutritionLog log) async {}

  @override
  List<NutritionLog> getNutritionLogHistory() => [];

  @override
  NutritionLog getTodayNutritionLog() => NutritionLog(id: 'today', date: DateTime.now());
}

class FakeAIChatRepository implements AIChatRepository {
  List<ChatMessage> _history = [
    ChatMessage(sender: 'bot', text: 'Welcome to Aizawl Gym!'),
  ];

  @override
  List<ChatMessage> getChatHistory() => List.from(_history);

  @override
  Future<void> saveChatHistory(List<ChatMessage> history) async {
    _history = List.from(history);
  }

  @override
  Future<void> clearChatHistory() async {
    _history.clear();
  }
}

class FakeNotificationRepository implements NotificationRepository {
  List<NotificationModel> _notifications = [
    NotificationModel(
      id: '101',
      title: 'Fake Notification',
      body: 'Test body',
      timestamp: 'Just now',
      isRead: false,
    ),
  ];

  @override
  List<NotificationModel> getNotifications() => List.from(_notifications);

  @override
  Future<void> saveNotifications(List<NotificationModel> list) async {
    _notifications = List.from(list);
  }

  @override
  bool hasUnreadNotifications() => _notifications.any((n) => !n.isRead);
}

void main() {
  group('Fake Repository Service/Provider Decoupling Tests', () {
    test('ProfileProvider operates cleanly with FakeProfileRepository', () async {
      final repo = FakeProfileRepository();
      final provider = ProfileProvider(repo);

      expect(provider.name, equals('Zothanmawia'));
      await provider.update({'name': 'Zothana', 'fitnessGoal': 'Strength'});
      expect(provider.name, equals('Zothana'));
      expect(repo.getProfile().fitnessGoal, equals('Strength'));
    });

    test('WorkoutService operates cleanly with FakeWorkoutRepository', () async {
      final repo = FakeWorkoutRepository();
      final service = WorkoutService(repo);

      final session = ActiveWorkoutSession(
        workoutName: 'Leg Day',
        workoutId: 'leg_101',
        currentIndex: 2,
        seconds: 300,
        isPaused: false,
        completedSets: [],
      );

      await service.saveActiveSession(session);
      expect(service.getActiveSession()?.workoutId, equals('leg_101'));

      await service.clearActiveSession();
      expect(service.getActiveSession(), isNull);
    });

    test('NutritionService operates cleanly with FakeNutritionRepository', () async {
      final repo = FakeNutritionRepository();
      final service = NutritionService(repo);

      expect(service.getProteinConsumed(), equals(0.0));
      await service.saveProteinConsumed(95.0);
      expect(service.getProteinConsumed(), equals(95.0));
      expect(repo.getProteinConsumed(), equals(95.0));
    });

    test('AIChatService operates cleanly with FakeAIChatRepository', () async {
      final repo = FakeAIChatRepository();
      final service = AIChatService(repo);

      expect(service.getChatHistory().length, equals(1));
      await service.saveChatHistory([
        ChatMessage(sender: 'user', text: 'Hello Fake'),
      ]);
      expect(service.getChatHistory().first.text, equals('Hello Fake'));

      await service.clearChatHistory();
      expect(service.getChatHistory(), isEmpty);
    });

    test('NotificationService operates cleanly with FakeNotificationRepository', () async {
      final repo = FakeNotificationRepository();
      final service = NotificationService(repo);

      expect(service.hasUnreadNotifications(), isTrue);
      final list = service.getNotifications();
      await service.markAllAsRead(list);
      expect(service.hasUnreadNotifications(), isFalse);
    });

    test('AppDependencies manual composition root initializes singleton defaults', () {
      final deps = AppDependencies.instance;
      expect(deps.profileProvider, isNotNull);
      expect(deps.workoutService, isNotNull);
      expect(deps.nutritionService, isNotNull);
      expect(deps.aiChatService, isNotNull);
      expect(deps.notificationService, isNotNull);
    });
  });
}
