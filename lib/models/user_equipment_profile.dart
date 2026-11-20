import 'equipment.dart';

/// User's personalized equipment access profile.
/// Represents all physical gym and home equipment available to the athlete.
class UserEquipmentProfile {
  final String userId;
  final List<String> availableEquipmentIds;
  final DateTime updatedAt;

  const UserEquipmentProfile({
    required this.userId,
    required this.availableEquipmentIds,
    required this.updatedAt,
  });

  /// Factory creating a default comprehensive commercial gym profile (all equipment available).
  factory UserEquipmentProfile.fullCommercialGym({
    String userId = 'local_user',
  }) {
    return UserEquipmentProfile(
      userId: userId,
      availableEquipmentIds: Equipment.masterCatalog()
          .map((e) => e.id)
          .toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Preset for home dumbbell & adjustable bench workout setup.
  factory UserEquipmentProfile.homeDumbbellsAndBench({
    String userId = 'local_user',
  }) {
    return UserEquipmentProfile(
      userId: userId,
      availableEquipmentIds: const [
        'dumbbells',
        'bench',
        'pull_up_bar',
        'resistance_bands',
        'exercise_mat',
        'ab_wheel',
      ],
      updatedAt: DateTime.now(),
    );
  }

  /// Preset for pure bodyweight and calisthenics training.
  factory UserEquipmentProfile.bodyweightCalisthenics({
    String userId = 'local_user',
  }) {
    return UserEquipmentProfile(
      userId: userId,
      availableEquipmentIds: const [
        'pull_up_bar',
        'dip_station',
        'exercise_mat',
        'resistance_bands',
        'ab_wheel',
      ],
      updatedAt: DateTime.now(),
    );
  }

  /// Preset for minimalist / travel workouts (no fixed equipment).
  factory UserEquipmentProfile.minimalist({String userId = 'local_user'}) {
    return UserEquipmentProfile(
      userId: userId,
      availableEquipmentIds: const ['exercise_mat', 'resistance_bands'],
      updatedAt: DateTime.now(),
    );
  }

  /// Checks if a specific piece of equipment is available in this profile.
  bool isEquipmentAvailable(String equipmentId) {
    if (equipmentId.isEmpty ||
        equipmentId.toLowerCase() == 'bodyweight' ||
        equipmentId.toLowerCase() == 'none') {
      return true;
    }
    return availableEquipmentIds.contains(equipmentId.toLowerCase());
  }

  /// Checks if ALL required equipment IDs are available in this profile.
  bool hasAllEquipment(List<String> requiredEquipmentIds) {
    if (requiredEquipmentIds.isEmpty) return true;
    for (final id in requiredEquipmentIds) {
      if (!isEquipmentAvailable(id)) {
        return false;
      }
    }
    return true;
  }

  /// Checks if at least ONE required equipment ID is available.
  bool hasAnyEquipment(List<String> requiredEquipmentIds) {
    if (requiredEquipmentIds.isEmpty) return true;
    for (final id in requiredEquipmentIds) {
      if (isEquipmentAvailable(id)) {
        return true;
      }
    }
    return false;
  }

  factory UserEquipmentProfile.fromJson(Map<String, dynamic> json) {
    final rawIds =
        json['availableEquipmentIds'] as List<dynamic>? ??
        (json['available_equipment_ids'] as List<dynamic>? ?? []);
    final ids = rawIds.map((e) => e.toString().toLowerCase()).toList();

    return UserEquipmentProfile(
      userId:
          json['userId'] as String? ??
          (json['user_id'] as String? ?? 'local_user'),
      availableEquipmentIds: ids.isNotEmpty
          ? ids
          : Equipment.masterCatalog().map((e) => e.id).toList(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'availableEquipmentIds': availableEquipmentIds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserEquipmentProfile copyWith({
    String? userId,
    List<String>? availableEquipmentIds,
    DateTime? updatedAt,
  }) {
    return UserEquipmentProfile(
      userId: userId ?? this.userId,
      availableEquipmentIds:
          availableEquipmentIds ?? List.from(this.availableEquipmentIds),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
