import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_history.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Pre-populate user profile and notifications if they do not exist
    if (_prefs?.getString('user_profile') == null) {
      await saveUserProfile(_getDefaultProfile());
    }
    if (_prefs?.getString('notifications_list') == null) {
      await saveNotifications(_getDefaultNotifications());
    }
  }

  // --- Protein Nutrition ---
  static double getProteinConsumed() {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final exists = _prefs?.containsKey('protein_consumed_$todayStr') ?? false;
    final todayVal = _prefs?.getDouble('protein_consumed_$todayStr');
    double result = 0.0;
    if (todayVal != null) {
      result = todayVal;
    } else {
      final lastDate = _prefs?.getString('protein_last_date');
      if (lastDate == todayStr) {
        result = _prefs?.getDouble('protein_consumed') ?? 0.0;
      }
    }
    debugPrint('[LocalStorage] today: $todayStr');
    debugPrint('[LocalStorage] protein_consumed_$todayStr exists: $exists');
    debugPrint('[LocalStorage] protein_consumed_$todayStr value: $todayVal');
    debugPrint('[LocalStorage] final value returned: $result');
    return result;
  }

  static double getProteinGoal() {
    return _prefs?.getDouble('protein_goal') ?? 140.0;
  }

  static Future<void> saveProteinConsumed(double val) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await _prefs?.setString('protein_last_date', todayStr);
    await _prefs?.setDouble('protein_consumed', val);
    await _prefs?.setDouble('protein_consumed_$todayStr', val);
  }

  static Future<void> saveProteinGoal(double val) async {
    await _prefs?.setDouble('protein_goal', val);
  }

  // --- Workout Session ---
  static Map<String, dynamic>? getActiveSession() {
    final str = _prefs?.getString('active_workout_session');
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> saveActiveSession(Map<String, dynamic> session) async {
    await _prefs?.setString('active_workout_session', jsonEncode(session));
  }

  static Future<void> clearActiveSession() async {
    await _prefs?.remove('active_workout_session');
  }

  // --- Workout History ---
  static List<WorkoutHistory> getWorkoutHistory() {
    final str = _prefs?.getString('workout_history');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => WorkoutHistory.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    final history = getWorkoutHistory()..add(entry);
    await _prefs?.setString(
      'workout_history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  // --- Auth State ---
  static bool isLoggedIn() {
    return _prefs?.getBool('is_logged_in') ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    await _prefs?.setBool('is_logged_in', value);
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
  }

  // --- UI User Profile ---
  static Map<String, dynamic> getUserProfile() {
    final str = _prefs?.getString('user_profile');
    if (str != null) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {
        return _getDefaultProfile();
      }
    }
    return _getDefaultProfile();
  }

  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    await _prefs?.setString('user_profile', jsonEncode(profile));
  }

  static Map<String, dynamic> _getDefaultProfile() {
    return {
      'name': 'Zothanmawia',
      'email': 'zothana@aizawlgym.com',
      'phone': '9876543210',
      'dob': '1995-10-15',
      'gender': 'Male',
      'height': '175',
      'weight': '68.2',
      'fitnessGoal': 'Build Muscle',
      'workoutExperience': 'Intermediate',
      'preferredDays': ['Monday', 'Wednesday', 'Friday'],
      'dietPreference': 'High Protein',
      'massUnit': 'kg',
      'lengthUnit': 'cm',
      'subscription': 'Free',
      'password': 'password123',
      'privacy': 'Friends Only',
      'notificationsEnabled': true,
      'profilePic': '', // no default image — falls back to icon
    };
  }

  // --- Notifications Model ---
  static List<Map<String, dynamic>> getNotifications() {
    final str = _prefs?.getString('notifications_list');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        return _getDefaultNotifications();
      }
    }
    return _getDefaultNotifications();
  }

  static Future<void> saveNotifications(List<Map<String, dynamic>> list) async {
    await _prefs?.setString('notifications_list', jsonEncode(list));
  }

  static List<Map<String, dynamic>> _getDefaultNotifications() {
    return [
      {
        'id': '1',
        'title': 'Workout Reminder',
        'body': 'Your Wednesday leg workout protocol begins in 30 minutes! Get ready.',
        'timestamp': '10 mins ago',
        'isRead': false,
      },
      {
        'id': '2',
        'title': 'Protein Goal Reached',
        'body': 'Impressive! You just reached your target consumption profile of 140g today.',
        'timestamp': '2 hours ago',
        'isRead': false,
      },
      {
        'id': '3',
        'title': 'Weekly Progress Report',
        'body': 'Consistency score increased by 12%! Your analytics chart has been generated.',
        'timestamp': '1 day ago',
        'isRead': false,
      },
      {
        'id': '4',
        'title': 'New Workout Generated',
        'body': 'AI Coach suggested a mobility block replacement for Goblet Squats.',
        'timestamp': '2 days ago',
        'isRead': true,
      },
      {
        'id': '5',
        'title': 'Subscription Renewal',
        'body': 'Your Pro plan will renew automatically on July 15th.',
        'timestamp': '4 days ago',
        'isRead': true,
      },
      {
        'id': '6',
        'title': 'Personal Best Achieved',
        'body': 'High intensity volume squat record unlocked: 120kg!',
        'timestamp': '1 week ago',
        'isRead': true,
      },
    ];
  }

  // --- AI Chat History ---
  static List<Map<String, dynamic>> getChatHistory() {
    final str = _prefs?.getString('chat_history');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        return _getDefaultChat();
      }
    }
    return _getDefaultChat();
  }

  static Future<void> saveChatHistory(List<Map<String, dynamic>> history) async {
    await _prefs?.setString('chat_history', jsonEncode(history));
  }

  static List<Map<String, dynamic>> _getDefaultChat() {
    return [
      {
        'sender': 'bot',
        'text': "I've reviewed your biometric data from yesterday's recovery cycle. Your heart rate variability is up by 8%, suggesting you're ready for a higher-intensity session today.",
        'tags': ['High Intensity Recommended', 'Restorative Focus']
      },
      {
        'sender': 'user',
        'text': "Thanks, Coach. I'm feeling a bit tight in my hip flexors after sitting all day. Should I adjust the warmup?"
      },
      {
        'sender': 'bot',
        'text': 'Absolutely. Let\'s integrate 5 minutes of "90/90 Hip Switches" and "Pigeon Pose" into your session. Precision in mobility prevents injury in performance.',
        'routineCard': true
      },
      {
        'sender': 'bot',
        'text': "Also, don't forget your post-workout hydration. Since today's session is more intense, aim for 20g of clean protein within 45 minutes of finishing to maximize muscle protein synthesis."
      }
    ];
  }
}
