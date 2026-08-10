/// Domain model representing a certified trainer profile, specializations, and assigned members.
class TrainerProfile {
  final String id;
  final String userId;
  final String gymId;
  final String displayName;
  final List<String> specializations;
  final List<String> assignedMemberIds;
  final String bio;
  final double rating;
  final int yearsExperience;
  final DateTime createdAt;

  const TrainerProfile({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.displayName,
    this.specializations = const ['Strength & Conditioning', 'Hypertrophy'],
    this.assignedMemberIds = const [],
    this.bio = 'Dedicated fitness coach empowering athletes to exceed their limits.',
    this.rating = 4.9,
    this.yearsExperience = 5,
    required this.createdAt,
  });

  /// Factory default trainer profile.
  factory TrainerProfile.defaultTrainer({
    String userId = 'usr_trainer_01',
    String gymId = 'gym_aizawl_01',
  }) {
    return TrainerProfile(
      id: 'tp_01',
      userId: userId,
      gymId: gymId,
      displayName: 'Coach Lalthanmawia',
      specializations: const [
        'Hypertrophy & Muscle Gain',
        'Strength & Powerlifting',
        'Recovery & Mobility',
      ],
      assignedMemberIds: const ['usr_local', 'usr_m_01', 'usr_m_02', 'usr_m_03'],
      bio: 'Senior Strength & Conditioning Head Coach at Aizawl Gym with 8+ years experience.',
      rating: 4.95,
      yearsExperience: 8,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  factory TrainerProfile.fromJson(Map<String, dynamic> json) {
    return TrainerProfile(
      id: json['id'] as String? ?? 'tp_01',
      userId: json['userId'] as String? ?? (json['user_id'] as String? ?? 'usr_trainer_01'),
      gymId: json['gymId'] as String? ?? (json['gym_id'] as String? ?? 'gym_aizawl_01'),
      displayName: json['displayName'] as String? ??
          (json['display_name'] as String? ?? 'Coach Lalthanmawia'),
      specializations: (json['specializations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      assignedMemberIds: (json['assignedMemberIds'] as List<dynamic>? ??
              (json['assigned_member_ids'] as List<dynamic>? ?? []))
          .map((e) => e.toString())
          .toList(),
      bio: json['bio'] as String? ?? 'Dedicated fitness coach.',
      rating: (json['rating'] as num? ?? 4.9).toDouble(),
      yearsExperience: json['yearsExperience'] as int? ??
          (json['years_experience'] as int? ?? 5),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'gymId': gymId,
        'displayName': displayName,
        'specializations': specializations,
        'assignedMemberIds': assignedMemberIds,
        'bio': bio,
        'rating': rating,
        'yearsExperience': yearsExperience,
        'createdAt': createdAt.toIso8601String(),
      };

  TrainerProfile copyWith({
    String? id,
    String? userId,
    String? gymId,
    String? displayName,
    List<String>? specializations,
    List<String>? assignedMemberIds,
    String? bio,
    double? rating,
    int? yearsExperience,
    DateTime? createdAt,
  }) {
    return TrainerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gymId: gymId ?? this.gymId,
      displayName: displayName ?? this.displayName,
      specializations: specializations ?? this.specializations,
      assignedMemberIds: assignedMemberIds ?? this.assignedMemberIds,
      bio: bio ?? this.bio,
      rating: rating ?? this.rating,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}
