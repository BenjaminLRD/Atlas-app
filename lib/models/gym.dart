/// Domain model representing a physical or virtual fitness facility hub.
class Gym {
  final String id;
  final String name;
  final String location;
  final String contactEmail;
  final String contactPhone;
  final int memberCount;
  final int trainerCount;
  final DateTime createdAt;

  const Gym({
    required this.id,
    required this.name,
    required this.location,
    required this.contactEmail,
    required this.contactPhone,
    this.memberCount = 0,
    this.trainerCount = 0,
    required this.createdAt,
  });

  /// Factory default Aizawl Gym facility hub.
  factory Gym.defaultGym() {
    return Gym(
      id: 'gym_aizawl_01',
      name: 'Aizawl Gym Main Hub',
      location: 'Zarkawt, Aizawl, Mizoram',
      contactEmail: 'contact@aizawlgym.com',
      contactPhone: '+91 98765 43210',
      memberCount: 248,
      trainerCount: 12,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as String? ?? 'gym_aizawl_01',
      name: json['name'] as String? ?? 'Aizawl Gym Main Hub',
      location: json['location'] as String? ?? 'Zarkawt, Aizawl',
      contactEmail: json['contactEmail'] as String? ??
          (json['contact_email'] as String? ?? 'contact@aizawlgym.com'),
      contactPhone: json['contactPhone'] as String? ??
          (json['contact_phone'] as String? ?? '+91 98765 43210'),
      memberCount: json['memberCount'] as int? ??
          (json['member_count'] as int? ?? 0),
      trainerCount: json['trainerCount'] as int? ??
          (json['trainer_count'] as int? ?? 0),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'memberCount': memberCount,
        'trainerCount': trainerCount,
        'createdAt': createdAt.toIso8601String(),
      };

  Gym copyWith({
    String? id,
    String? name,
    String? location,
    String? contactEmail,
    String? contactPhone,
    int? memberCount,
    int? trainerCount,
    DateTime? createdAt,
  }) {
    return Gym(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      memberCount: memberCount ?? this.memberCount,
      trainerCount: trainerCount ?? this.trainerCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gym &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
