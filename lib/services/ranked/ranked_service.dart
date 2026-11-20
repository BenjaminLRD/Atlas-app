import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/local_storage.dart';
import '../cloud/cloud_session.dart';
import '../cloud/cloud_sync_queue.dart';
import 'ranked_catalog.dart';
import 'ranked_evaluator.dart';
import 'ranked_progress_store.dart';

/// One row of the Ranked leaderboard.
class RankedLeaderboardRow {
  final String userId;
  final String displayName;
  final int points;

  const RankedLeaderboardRow({
    required this.userId,
    required this.displayName,
    required this.points,
  });
}

class RankedException implements Exception {
  final String message;
  const RankedException(this.message);

  @override
  String toString() => message;
}

/// Ranked mode on the device.
///
/// The device evaluates milestones from its own data to show progress, but
/// rank only counts what the `ranked-sync` Edge Function verified from synced
/// data. Without a backend (local-only builds) the device estimate is shown
/// and marked unverified.
class RankedService extends ChangeNotifier {
  static RankedService? _instance;
  static RankedService get instance => _instance ??= RankedService();
  static void setInstance(RankedService service) => _instance = service;

  RankedCatalog? _catalog;
  RankedEvaluation? _local;
  RankedSnapshot _snapshot = RankedProgressStore.current;
  bool _busy = false;
  String? _error;

  RankedCatalog? get catalog => _catalog;
  RankedEvaluation? get localEvaluation => _local;
  RankedSnapshot get snapshot => _snapshot;
  bool get isBusy => _busy;
  String? get error => _error;

  /// True when rank can be verified by the server.
  bool get canVerify => CloudSession.client != null;

  /// Body weight and gender used for strength targets.
  String get gender => LocalStorage.getUserProfile().gender;

  /// Re-evaluates local progress and, when signed in, syncs with the server.
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final catalog = _catalog ??= await RankedCatalog.load();
      _local = evaluateLocal(catalog);
      if (canVerify && CloudSession.userId != null) {
        await _syncWithServer();
      } else if (!canVerify) {
        _snapshot = RankedSnapshot(
          points: _local!.points,
          statLevels: _local!.statLevels,
          verified: false,
          updatedAt: DateTime.now(),
        );
        await RankedProgressStore.save(_snapshot);
      }
    } catch (e) {
      _error = e is RankedException
          ? e.message
          : 'Could not update your rank. Check your connection and try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Milestone progress from this device's workouts and cardio sessions.
  RankedEvaluation evaluateLocal(RankedCatalog catalog) {
    final profile = LocalStorage.getUserProfile();
    return RankedEvaluator(catalog).evaluate(
      history: LocalStorage.getWorkoutHistory(),
      sessions: LocalStorage.getWorkoutSessions(),
      cardio: LocalStorage.getCardioSessions(),
      bodyweight: double.tryParse(
        profile.weight.replaceAll(RegExp('[^0-9.]'), ''),
      ),
      gender: profile.gender,
    );
  }

  /// Uploads a proof video for a milestone level that needs one and sends it
  /// for review.
  Future<void> submitProof({
    required String milestoneId,
    required int level,
    required File video,
  }) async {
    final client = CloudSession.client;
    final uid = CloudSession.userId;
    if (client == null || uid == null) {
      throw const RankedException('Sign in to submit a video.');
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final ext = video.path.split('.').last.toLowerCase();
      final path =
          '$uid/${milestoneId}_${level}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await client.storage.from('ranked-proofs').upload(path, video);
      await _syncWithServer(
        video: {'milestone_id': milestoneId, 'level': level, 'path': path},
      );
    } catch (e) {
      _error = e is RankedException
          ? e.message
          : 'The video could not be uploaded. Try again.';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Top of the Ranked leaderboard (signed-in users only).
  Future<List<RankedLeaderboardRow>> leaderboard({int limit = 50}) async {
    final client = CloudSession.client;
    if (client == null || CloudSession.userId == null) return const [];
    final rows = await client
        .from('ranked_profiles')
        .select('user_id, display_name, points')
        .gt('points', 0)
        .order('points', ascending: false)
        .order('updated_at')
        .limit(limit);
    return [
      for (final r in rows)
        RankedLeaderboardRow(
          userId: r['user_id'] as String,
          displayName: (r['display_name'] as String?)?.isNotEmpty == true
              ? r['display_name'] as String
              : 'Athlete',
          points: (r['points'] as num).toInt(),
        ),
    ];
  }

  Future<void> _syncWithServer({Map<String, Object>? video}) async {
    final client = CloudSession.client!;
    // The server judges synced data, so push local changes first.
    await CloudSyncQueue.instance.flush();
    final response = await client.functions.invoke(
      'ranked-sync',
      body: video == null ? const {} : {'video': video},
    );
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final message = data is Map ? data['error'] as String? : null;
      throw RankedException(message ?? 'Could not reach the Ranked server.');
    }
    _snapshot = RankedSnapshot.fromJson({
      ...Map<String, dynamic>.from(data),
      'verified': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await RankedProgressStore.save(_snapshot);
    debugPrint('[RankedService] verified points: ${_snapshot.points}');
  }
}
