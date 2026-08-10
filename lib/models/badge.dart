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

  /// Helper getter to construct Flutter IconData
  // ignore: non_const_argument_for_const_parameter
  IconData get iconData => IconData(iconCodePoint, fontFamily: iconFontFamily);

  factory AchievementBadge.fromJson(Map<String, dynamic> json) {
    return AchievementBadge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
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
