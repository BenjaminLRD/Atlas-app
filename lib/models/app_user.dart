/// User identity model for Aizawl Gym session management.
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Gym Member',
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          profileImageUrl == other.profileImageUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      profileImageUrl.hashCode;
}
