import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/local_storage.dart';

/// Single offline action item queued for background replay once online.
class QueuedAction {
  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  QueuedAction({
    required this.id,
    required this.actionType,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'] as String? ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
      actionType: json['actionType'] as String? ?? 'general',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };
}

/// Offline action queue service managing background retry synchronization.
class OfflineActionQueue {
  static final OfflineActionQueue _instance = OfflineActionQueue._internal();
  factory OfflineActionQueue() => _instance;
  OfflineActionQueue._internal();

  static OfflineActionQueue get instance => _instance;

  final List<QueuedAction> _queue = [];

  List<QueuedAction> get pendingActions => List.unmodifiable(_queue);

  /// Initializes queue from local storage.
  void init() {
    final raw = LocalStorage.getOfflineQueue();
    _queue.clear();
    _queue.addAll(raw.map((e) => QueuedAction.fromJson(e)));
  }

  /// Enqueues an offline action.
  Future<QueuedAction> enqueueAction(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final action = QueuedAction(
      id: 'action_${DateTime.now().millisecondsSinceEpoch}',
      actionType: actionType,
      payload: payload,
    );
    _queue.add(action);
    await _persist();
    debugPrint('[OfflineActionQueue] Enqueued action: $actionType (Queue length: ${_queue.length})');
    return action;
  }

  /// Attempts to process and flush pending offline actions via custom handler.
  Future<int> processQueue(Future<bool> Function(QueuedAction action) handler) async {
    if (_queue.isEmpty) return 0;

    int successCount = 0;
    final List<QueuedAction> remaining = [];

    for (final action in _queue) {
      try {
        final success = await handler(action);
        if (success) {
          successCount++;
        } else {
          action.retryCount++;
          if (action.retryCount < 5) {
            remaining.add(action);
          }
        }
      } catch (e) {
        action.retryCount++;
        if (action.retryCount < 5) {
          remaining.add(action);
        }
      }
    }

    _queue.clear();
    _queue.addAll(remaining);
    await _persist();
    return successCount;
  }

  /// Clears pending action queue.
  Future<void> clearQueue() async {
    _queue.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final jsonList = _queue.map((a) => a.toJson()).toList();
    await LocalStorage.saveOfflineQueue(jsonList);
  }
}
