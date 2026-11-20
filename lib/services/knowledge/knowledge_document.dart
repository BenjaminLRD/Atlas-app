/// Categories of curated fitness science knowledge.
enum KnowledgeCategory {
  training('TRAINING'),
  nutrition('NUTRITION'),
  exerciseScience('EXERCISE_SCIENCE'),
  recovery('RECOVERY'),
  safety('SAFETY');

  final String code;
  const KnowledgeCategory(this.code);

  static KnowledgeCategory fromCode(String code) {
    return KnowledgeCategory.values.firstWhere(
      (e) =>
          e.code.toUpperCase() == code.toUpperCase() ||
          e.name.toLowerCase() == code.toLowerCase(),
      orElse: () => KnowledgeCategory.training,
    );
  }
}

/// A structured knowledge document in the Atlas private AI fitness corpus.
class KnowledgeDocument {
  final String id;
  final String title;
  final KnowledgeCategory category;
  final String content;
  final String source; // e.g. "NSCA Essentials of Strength & Conditioning", "ISSN Protein Stand"
  final List<double>? embedding; // Dense float vector compatible with pgvector
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const KnowledgeDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.source,
    this.embedding,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  KnowledgeDocument copyWith({
    String? id,
    String? title,
    KnowledgeCategory? category,
    String? content,
    String? source,
    List<double>? embedding,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return KnowledgeDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      source: source ?? this.source,
      embedding: embedding ?? this.embedding,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.code,
    'content': content,
    'source': source,
    if (embedding != null) 'embedding': embedding,
    'tags': tags,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocument(
      id: json['id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? '',
      category: KnowledgeCategory.fromCode(
        json['category']?.toString() ?? 'TRAINING',
      ),
      content: json['content']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Atlas Sports Science Institute',
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
