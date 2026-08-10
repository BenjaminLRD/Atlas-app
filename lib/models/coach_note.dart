/// Model representing professional coach notes and observation logs attached to a member.
class CoachNote {
  final String id;
  final String trainerId;
  final String memberId;
  final String noteText;
  final String category; // 'training', 'nutrition', 'injury', 'general'
  final DateTime createdAt;

  const CoachNote({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.noteText,
    this.category = 'general',
    required this.createdAt,
  });

  factory CoachNote.fromJson(Map<String, dynamic> json) {
    return CoachNote(
      id: json['id'] as String? ?? '',
      trainerId: json['trainerId'] as String? ?? (json['trainer_id'] as String? ?? ''),
      memberId: json['memberId'] as String? ?? (json['member_id'] as String? ?? ''),
      noteText: json['noteText'] as String? ?? (json['note_text'] as String? ?? ''),
      category: json['category'] as String? ?? 'general',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trainerId': trainerId,
        'memberId': memberId,
        'noteText': noteText,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
      };

  CoachNote copyWith({
    String? id,
    String? trainerId,
    String? memberId,
    String? noteText,
    String? category,
    DateTime? createdAt,
  }) {
    return CoachNote(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      memberId: memberId ?? this.memberId,
      noteText: noteText ?? this.noteText,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          noteText == other.noteText;

  @override
  int get hashCode => id.hashCode ^ noteText.hashCode;
}
