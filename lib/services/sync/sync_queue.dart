import 'dart:convert';

/// Represents a discrete pending sync operation to be flushed to remote cloud storage.
class SyncOperation {
  final String operationId;
  final String type; // e.g. 'upload', 'delete', 'update'
  final String key;
  final DateTime createdAt;
  final dynamic payload;

  SyncOperation({
    required this.operationId,
    required this.type,
    required this.key,
    DateTime? createdAt,
    this.payload,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'type': type,
        'key': key,
        'createdAt': createdAt.toIso8601String(),
        'payload': payload,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      operationId: json['operationId'] as String,
      type: json['type'] as String,
      key: json['key'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      payload: json['payload'],
    );
  }

  @override
  String toString() =>
      'SyncOperation(id: $operationId, type: $type, key: $key, createdAt: $createdAt)';
}

/// Queue to store and manage pending synchronization operations.
class SyncQueue {
  final List<SyncOperation> _operations = [];

  /// Get unmodifiable list of pending operations.
  List<SyncOperation> get pendingOperations => List.unmodifiable(_operations);

  int get length => _operations.length;
  bool get isEmpty => _operations.isEmpty;
  bool get isNotEmpty => _operations.isNotEmpty;

  /// Enqueue a pending sync operation. Overwrites any pending operation with matching key and type.
  void addOperation(SyncOperation operation) {
    _operations.removeWhere(
        (op) => op.key == operation.key && op.type == operation.type);
    _operations.add(operation);
  }

  /// Remove a specific operation from queue by [operationId].
  bool removeOperation(String operationId) {
    final countBefore = _operations.length;
    _operations.removeWhere((op) => op.operationId == operationId);
    return _operations.length < countBefore;
  }

  /// Retrieve all pending operations.
  List<SyncOperation> getPendingOperations() {
    return List.unmodifiable(_operations);
  }

  /// Clear all queued operations.
  void clear() {
    _operations.clear();
  }

  /// Serialize queue to JSON string for local persistence.
  String toJsonString() {
    return jsonEncode(_operations.map((op) => op.toJson()).toList());
  }

  /// Populate queue from JSON string.
  void loadFromJsonString(String jsonStr) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      _operations.clear();
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _operations.add(SyncOperation.fromJson(item));
        }
      }
    } catch (_) {}
  }
}
