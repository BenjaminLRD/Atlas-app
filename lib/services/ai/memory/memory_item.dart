/// Four core categories of long-term athlete intelligence memory.
enum MemoryCategory {
  behaviorPattern('BEHAVIOR_PATTERN'),
  successfulStrategy('SUCCESSFUL_STRATEGY'),
  trainingPreference('TRAINING_PREFERENCE'),
  historicalDecision('HISTORICAL_DECISION');

  final String code;
  const MemoryCategory(this.code);

  static MemoryCategory fromCode(String code) {
    return MemoryCategory.values.firstWhere(
      (e) =>
          e.code.toUpperCase() == code.toUpperCase() ||
          e.name.toLowerCase() == code.toLowerCase(),
      orElse: () => MemoryCategory.behaviorPattern,
    );
  }
}

/// An individual unit of long-term semantic coaching intelligence.
class MemoryItem {
  final String id;
  final MemoryCategory category;
  final String title;
  final String content;
  final double importanceScore; // 1.0 to 10.0 scale
  final double confidenceScore; // 0.0 to 1.0 scale
  final List<String> tags;
  final String
  source; // 'user_feedback', 'decision_engine', 'workout_execution', 'coach_action'
  final DateTime createdAt;
  final DateTime? lastAccessedAt;
  final DateTime? expiresAt; // Optional TTL for transient memories
  final int accessCount;

  const MemoryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.importanceScore,
    this.confidenceScore = 0.9,
    this.tags = const [],
    this.source = 'user_feedback',
    required this.createdAt,
    this.lastAccessedAt,
    this.expiresAt,
    this.accessCount = 0,
  });

  /// Indicates if this memory item has exceeded its temporal lifespan (TTL).
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  MemoryItem copyWith({
    String? id,
    MemoryCategory? category,
    String? title,
    String? content,
    double? importanceScore,
    double? confidenceScore,
    List<String>? tags,
    String? source,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
    int? accessCount,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      content: content ?? this.content,
      importanceScore: importanceScore ?? this.importanceScore,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      accessCount: accessCount ?? this.accessCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.code,
    'title': title,
    'content': content,
    'importance_score': importanceScore,
    'confidence_score': confidenceScore,
    'tags': tags,
    'source': source,
    'created_at': createdAt.toIso8601String(),
    if (lastAccessedAt != null)
      'last_accessed_at': lastAccessedAt!.toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    'access_count': accessCount,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id:
          json['id']?.toString() ??
          'mem_${DateTime.now().millisecondsSinceEpoch}',
      category: MemoryCategory.fromCode(
        json['category']?.toString() ?? 'BEHAVIOR_PATTERN',
      ),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      importanceScore: (json['importance_score'] as num?)?.toDouble() ?? 5.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.9,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      source: json['source']?.toString() ?? 'user_feedback',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.tryParse(json['last_accessed_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      accessCount: (json['access_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Helper for calculating semantic importance scores (1.0 to 10.0).
class MemoryImportanceScorer {
  /// Computes base importance based on category and contextual impact.
  static double calculateScore({
    required MemoryCategory category,
    bool userConfirmed = false,
    bool isPrOrMilestone = false,
    bool isInjuryOrSafetyRelated = false,
    int repetitionCount = 1,
  }) {
    double baseScore;
    switch (category) {
      case MemoryCategory.successfulStrategy:
        baseScore = 7.5;
        break;
      case MemoryCategory.behaviorPattern:
        baseScore = 6.0;
        break;
      case MemoryCategory.trainingPreference:
        baseScore = 6.5;
        break;
      case MemoryCategory.historicalDecision:
        baseScore = 5.5;
        break;
    }

    if (userConfirmed) baseScore += 1.5;
    if (isPrOrMilestone) baseScore += 1.5;
    if (isInjuryOrSafetyRelated) baseScore += 2.0;

    // Small frequency boost for repeated patterns
    if (repetitionCount > 1) {
      baseScore += (repetitionCount * 0.2);
    }

    return baseScore.clamp(1.0, 10.0);
  }
}
