/// Model representing a paired or connected wearable health device (Apple Watch, Pixel Watch, Garmin, Fitbit, etc.).
class ConnectedDevice {
  final String id;
  final String name;
  final String type; // 'apple_health', 'google_fit', 'fitbit', 'garmin', 'mock'
  final bool isConnected;
  final DateTime? lastSynced;
  final int? batteryLevel;
  final String iconName;

  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
    this.lastSynced,
    this.batteryLevel,
    this.iconName = 'watch',
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Wearable Device',
      type: json['type'] as String? ?? 'mock',
      isConnected: json['isConnected'] as bool? ?? (json['is_connected'] as bool? ?? false),
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'] as String)
          : (json['last_synced'] != null
              ? DateTime.parse(json['last_synced'] as String)
              : null),
      batteryLevel: json['batteryLevel'] as int? ?? (json['battery_level'] as int?),
      iconName: json['iconName'] as String? ?? (json['icon_name'] as String? ?? 'watch'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'isConnected': isConnected,
        'lastSynced': lastSynced?.toIso8601String(),
        'batteryLevel': batteryLevel,
        'iconName': iconName,
      };

  ConnectedDevice copyWith({
    String? id,
    String? name,
    String? type,
    bool? isConnected,
    DateTime? lastSynced,
    int? batteryLevel,
    String? iconName,
  }) {
    return ConnectedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      lastSynced: lastSynced ?? this.lastSynced,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      iconName: iconName ?? this.iconName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectedDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          isConnected == other.isConnected;

  @override
  int get hashCode => id.hashCode ^ type.hashCode ^ isConnected.hashCode;
}
