enum UserRole {
  member,
  trainer,
  admin,
}

extension UserRoleExtension on UserRole {
  String get roleKey {
    switch (this) {
      case UserRole.member:
        return 'member';
      case UserRole.trainer:
        return 'trainer';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.member:
        return 'Gym Member';
      case UserRole.trainer:
        return 'Fitness Trainer';
      case UserRole.admin:
        return 'Gym Administrator';
    }
  }

  bool get isMember => this == UserRole.member;
  bool get isTrainer => this == UserRole.trainer || this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.member;
    switch (value.toLowerCase().trim()) {
      case 'trainer':
      case 'coach':
        return UserRole.trainer;
      case 'admin':
      case 'administrator':
      case 'owner':
        return UserRole.admin;
      case 'member':
      default:
        return UserRole.member;
    }
  }
}
