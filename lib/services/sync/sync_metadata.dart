/// Status of remote synchronization.
enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

/// Metadata tracking the synchronization state of the local device.
class SyncMetadata {
  final DateTime? lastSyncTime;
  final SyncStatus syncStatus;
  final int pendingChanges;
  final String deviceId;
  final String? lastError;

  const SyncMetadata({
    this.lastSyncTime,
    this.syncStatus = SyncStatus.synced,
    this.pendingChanges = 0,
    required this.deviceId,
    this.lastError,
  });

  /// Create initial default metadata for local device.
  factory SyncMetadata.initial({String? deviceId}) {
    return SyncMetadata(
      lastSyncTime: null,
      syncStatus: SyncStatus.synced,
      pendingChanges: 0,
      deviceId: deviceId ?? 'device_local_01',
      lastError: null,
    );
  }

  /// Create copy of [SyncMetadata] with modified parameters.
  SyncMetadata copyWith({
    DateTime? lastSyncTime,
    SyncStatus? syncStatus,
    int? pendingChanges,
    String? deviceId,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncMetadata(
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      deviceId: deviceId ?? this.deviceId,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'pendingChanges': pendingChanges,
      'deviceId': deviceId,
      'lastError': lastError,
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
      pendingChanges: (json['pendingChanges'] as num?)?.toInt() ?? 0,
      deviceId: (json['deviceId'] as String?) ?? 'device_local_01',
      lastError: json['lastError'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncMetadata &&
          runtimeType == other.runtimeType &&
          lastSyncTime == other.lastSyncTime &&
          syncStatus == other.syncStatus &&
          pendingChanges == other.pendingChanges &&
          deviceId == other.deviceId &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      lastSyncTime.hashCode ^
      syncStatus.hashCode ^
      pendingChanges.hashCode ^
      deviceId.hashCode ^
      lastError.hashCode;

  @override
  String toString() =>
      'SyncMetadata(lastSyncTime: $lastSyncTime, syncStatus: $syncStatus, pendingChanges: $pendingChanges, deviceId: $deviceId, lastError: $lastError)';
}
