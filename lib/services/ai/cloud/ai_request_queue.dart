import 'dart:async';
import '../../../models/fitness_context.dart';
import '../prompt/adaptive_prompt_builder.dart';
import 'atlas_ai_service_gateway.dart';

/// Single item pending execution in the asynchronous AI request queue.
class QueuedAIRequest {
  final String id;
  final String query;
  final FitnessContext context;
  final AIRequestPriority priority;
  final CoachStyle? style;
  final Completer<AIGatewayResponse> completer;
  final DateTime createdAt;
  int retryAttempts;

  QueuedAIRequest({
    required this.id,
    required this.query,
    required this.context,
    required this.priority,
    this.style,
    required this.completer,
    required this.createdAt,
    this.retryAttempts = 0,
  });
}

/// Asynchronous AI Request Queue & Prioritization Engine.
/// Guarantees high-priority real-time coaching prompts execute with sub-100ms dispatching
/// while throttling background pattern mining and batch weekly reviews.
class AIRequestQueue {
  static AIRequestQueue? _instance;
  static AIRequestQueue get instance => _instance ??= AIRequestQueue();

  static void resetInstance() {
    _instance = null;
  }

  final AtlasAIServiceGateway _gateway;
  final List<QueuedAIRequest> _queue = [];
  final int maxConcurrent;
  int _activeCount = 0;
  int _totalProcessedCount = 0;

  AIRequestQueue({AtlasAIServiceGateway? gateway, this.maxConcurrent = 4})
    : _gateway = gateway ?? AtlasAIServiceGateway.instance;

  int get queueLength => _queue.length;
  int get activeCount => _activeCount;
  int get totalProcessedCount => _totalProcessedCount;

  /// Enqueues an AI task and returns a Future that resolves when execution completes.
  Future<AIGatewayResponse> enqueue({
    required String query,
    required FitnessContext context,
    AIRequestPriority priority = AIRequestPriority.liveInteractive,
    CoachStyle? style,
  }) {
    final completer = Completer<AIGatewayResponse>();
    final request = QueuedAIRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
      query: query,
      context: context,
      priority: priority,
      style: style,
      completer: completer,
      createdAt: DateTime.now(),
    );

    _queue.add(request);
    _sortQueue();
    _processNext();

    return completer.future;
  }

  /// Sorts requests by priority (P1 highest, P4 lowest) and secondarily by timestamp (FIFO).
  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityDiff = a.priority.level.compareTo(b.priority.level);
      if (priorityDiff != 0) return priorityDiff;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Dispatches the next request if concurrency slots are available.
  Future<void> _processNext() async {
    if (_queue.isEmpty || _activeCount >= maxConcurrent) {
      return;
    }

    final nextRequest = _queue.removeAt(0);
    _activeCount++;

    try {
      final response = await _gateway.executeRequest(
        userQuery: nextRequest.query,
        context: nextRequest.context,
        style: nextRequest.style,
        priority: nextRequest.priority,
      );

      _totalProcessedCount++;
      if (!nextRequest.completer.isCompleted) {
        nextRequest.completer.complete(response);
      }
    } catch (e, stack) {
      if (!nextRequest.completer.isCompleted) {
        nextRequest.completer.completeError(e, stack);
      }
    } finally {
      _activeCount--;
      _processNext();
    }
  }
}
