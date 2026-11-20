import 'package:flutter/material.dart';

/// Achievement Badge model representing earnable rewards, trophies, and milestones.
class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final String iconFontFamily;
  final String category;
  final String rarity;
  final DateTime? earnedDate;
  final bool isUnlocked;
  final String? imageUrl;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.category,
    required this.rarity,
    this.earnedDate,
    this.isUnlocked = true,
    this.imageUrl,
  });

  /// Static lookup mapping icon code points to compile-time constant IconData
  static final Map<int, IconData> _codePointMap = {
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.celebration_rounded.codePoint: Icons.celebration_rounded,
    Icons.workspace_premium_rounded.codePoint: Icons.workspace_premium_rounded,
    Icons.local_fire_department_rounded.codePoint:
        Icons.local_fire_department_rounded,
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.emoji_events_rounded.codePoint: Icons.emoji_events_rounded,
    Icons.rice_bowl_rounded.codePoint: Icons.rice_bowl_rounded,
    Icons.military_tech_rounded.codePoint: Icons.military_tech_rounded,
    Icons.star_rounded.codePoint: Icons.star_rounded,
    Icons.lock_rounded.codePoint: Icons.lock_rounded,
    Icons.check_circle_rounded.codePoint: Icons.check_circle_rounded,
    Icons.bolt_rounded.codePoint: Icons.bolt_rounded,
    Icons.shield_rounded.codePoint: Icons.shield_rounded,
    Icons.trending_up_rounded.codePoint: Icons.trending_up_rounded,
    Icons.timer_rounded.codePoint: Icons.timer_rounded,
    Icons.speed_rounded.codePoint: Icons.speed_rounded,
    Icons.directions_run_rounded.codePoint: Icons.directions_run_rounded,
    Icons.whatshot_rounded.codePoint: Icons.whatshot_rounded,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.celebration.codePoint: Icons.celebration,
    Icons.emoji_events.codePoint: Icons.emoji_events,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.local_fire_department.codePoint: Icons.local_fire_department,
    Icons.star.codePoint: Icons.star,
  };

  /// Static lookup mapping badge IDs to compile-time constant IconData
  static const Map<String, IconData> _idMap = {
    'first_workout': Icons.fitness_center_rounded,
    'workouts_10': Icons.celebration_rounded,
    'workouts_100': Icons.workspace_premium_rounded,
    'streak_7': Icons.local_fire_department_rounded,
    'nutrition_master': Icons.restaurant_rounded,
    'personal_record': Icons.emoji_events_rounded,
    'first_meal': Icons.restaurant_rounded,
    'meals_10': Icons.rice_bowl_rounded,
    'protein_master': Icons.fitness_center_rounded,
    'nutrition_streak_7': Icons.local_fire_department_rounded,
    'nutrition_streak_30': Icons.workspace_premium_rounded,
  };

  /// Static const IconData lookup preventing non-constant IconData construction
  IconData get iconData =>
      _codePointMap[iconCodePoint] ?? _idMap[id] ?? Icons.emoji_events_rounded;

  factory AchievementBadge.fromJson(Map<String, dynamic> json) {
    return AchievementBadge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconCodePoint:
          (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.emoji_events_rounded.codePoint,
      iconFontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      category: json['category'] as String? ?? 'General',
      rarity: json['rarity'] as String? ?? 'Common',
      earnedDate: json['earnedDate'] != null
          ? DateTime.tryParse(json['earnedDate'].toString())
          : null,
      isUnlocked: json['isUnlocked'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'category': category,
      'rarity': rarity,
      'earnedDate': earnedDate?.toIso8601String(),
      'isUnlocked': isUnlocked,
      'imageUrl': imageUrl,
    };
  }

  AchievementBadge copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    String? category,
    String? rarity,
    DateTime? earnedDate,
    bool? isUnlocked,
    String? imageUrl,
  }) {
    return AchievementBadge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      earnedDate: earnedDate ?? this.earnedDate,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
