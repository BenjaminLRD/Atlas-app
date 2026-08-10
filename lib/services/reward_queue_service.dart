import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/badge.dart';
import '../models/reward_event.dart';
import '../models/weekly_challenge.dart';
import '../widgets/common/achievement_unlock_dialog.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/rank_up_dialog.dart';

import '../widgets/common/reward_celebration_overlay.dart';

/// Service responsible for managing, ordering, deduplicating, and sequentially
/// presenting post-workout and gamification reward events.
class RewardQueueService {
  static RewardQueueService? _instance;

  final List<RewardEvent> _queue = [];
  final Set<String> _processedIds = {};
  bool _isProcessing = false;

  RewardQueueService._() {
    _loadProcessedIds();
  }

  /// Reset singleton instance (useful for unit testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Global singleton instance for RewardQueueService
  static RewardQueueService get instance {
    _instance ??= RewardQueueService._();
    return _instance!;
  }

  /// Factory constructor returning singleton instance
  factory RewardQueueService() {
    _instance ??= RewardQueueService._();
    return _instance!;
  }

  /// Load persisted processed reward IDs from LocalStorage
  void _loadProcessedIds() {
    final saved = LocalStorage.getProcessedRewardIds();
    _processedIds.addAll(saved);
  }

  /// Save processed reward IDs to LocalStorage for persistence across app restarts
  Future<void> _saveProcessedIds() async {
    await LocalStorage.saveProcessedRewardIds(_processedIds.toList());
  }

  /// Enqueue a single reward event while enforcing queue order and duplicate prevention.
  /// Returns `true` if the event was successfully enqueued, or `false` if it was ignored as a duplicate.
  bool enqueue(RewardEvent event) {
    // Duplicate prevention: Skip if reward has already been processed or is already in the queue
    if (_processedIds.contains(event.id) || _queue.any((e) => e.id == event.id)) {
      return false;
    }

    _queue.add(event);
    _sortQueue();
    return true;
  }

  /// Enqueue a list of reward events.
  /// Returns the number of new events successfully added to the queue.
  int enqueueAll(List<RewardEvent> events) {
    int added = 0;
    for (final event in events) {
      if (enqueue(event)) {
        added++;
      }
    }
    return added;
  }

  /// Sort queue in descending order of priority (higher priority first),
  /// using timestamp as a secondary tie-breaker.
  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.timestamp.compareTo(b.timestamp);
    });
  }

  /// Expose next pending reward without removing it from the queue
  RewardEvent? peek() => _queue.isNotEmpty ? _queue.first : null;

  /// Getter for the next pending reward
  RewardEvent? get nextReward => peek();

  /// Check whether there are pending reward events in the queue
  bool get hasPendingRewards => _queue.isNotEmpty;

  /// Total count of pending reward events
  int get pendingCount => _queue.length;

  /// Check whether the queue processor is actively presenting dialogs
  bool get isProcessing => _isProcessing;

  /// Unmodifiable view of currently queued reward events
  List<RewardEvent> get queue => List.unmodifiable(_queue);

  /// Dequeue next reward event, mark it as processed, and persist its ID
  RewardEvent? dequeue() {
    if (_queue.isEmpty) return null;
    final event = _queue.removeAt(0);
    _processedIds.add(event.id);
    _saveProcessedIds();
    return event;
  }

  /// Clear all currently pending rewards from the queue
  void clearQueue() {
    _queue.clear();
  }

  /// Clear recorded processed IDs cache
  Future<void> clearProcessedHistory() async {
    _processedIds.clear();
    await _saveProcessedIds();
  }

  /// Sequentially process and display all queued reward dialogs on the active BuildContext
  Future<void> processQueue(BuildContext context) async {
    if (_isProcessing || !hasPendingRewards) return;

    _isProcessing = true;

    try {
      while (hasPendingRewards) {
        if (!context.mounted) break;
        final reward = dequeue();
        if (reward == null) break;

        await _displayRewardDialog(context, reward);
        
        if (!context.mounted) break;

        // Small padding transition between consecutive dialogs for smooth UX
        if (hasPendingRewards) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Dispatch reward presentation to appropriate dialog widget
  Future<void> _displayRewardDialog(BuildContext context, RewardEvent reward) async {
    if (!context.mounted) return;

    switch (reward.type) {
      case RewardType.rankUp:
        if (reward.data is RankUpDetails) {
          await RankUpDialog.show(context, reward.data as RankUpDetails);
        }
        break;

      case RewardType.achievement:
        if (reward.data is AchievementBadge) {
          await AchievementUnlockDialog.show(context, reward.data as AchievementBadge);
        }
        break;

      case RewardType.xpBonus:
        final amount = reward.data is Map ? (reward.data['amount'] as int? ?? 100) : 100;
        final source = reward.data is Map ? (reward.data['source'] as String? ?? 'Workout') : 'Bonus';
        await RewardCelebrationOverlay.show(
          context,
          title: 'XP BONUS UNLOCKED!',
          description: 'You gained bonus XP for $source',
          xpGained: amount,
          icon: Icons.bolt_rounded,
        );
        break;

      case RewardType.weeklyChallenge:
        if (reward.data is WeeklyChallenge) {
          await _showWeeklyChallengeDialog(context, reward.data as WeeklyChallenge);
        } else {
          await _showWeeklyChallengeDialog(
            context,
            WeeklyChallenge(
              id: reward.id,
              title: reward.title,
              description: 'Completed weekly challenge',
              category: 'Weekly',
              targetValue: 1.0,
              currentProgress: 1.0,
              xpReward: 500,
              completed: true,
            ),
          );
        }
        break;

      case RewardType.dailyQuest:
        await RewardCelebrationOverlay.show(
          context,
          title: 'DAILY QUEST COMPLETE!',
          description: reward.title,
          xpGained: 250,
          icon: Icons.task_alt_rounded,
        );
        break;

      case RewardType.seasonalReward:
        await RewardCelebrationOverlay.show(
          context,
          title: 'SEASONAL REWARD!',
          description: reward.title,
          xpGained: 500,
          icon: Icons.military_tech_rounded,
        );
        break;

      case RewardType.battlePass:
        await RewardCelebrationOverlay.show(
          context,
          title: 'BATTLE PASS TIER UNLOCKED!',
          description: reward.title,
          xpGained: 300,
          icon: Icons.workspace_premium_rounded,
        );
        break;

      case RewardType.referralReward:
        final amount = reward.data is Map ? (reward.data['amount'] as int? ?? 500) : 500;
        await RewardCelebrationOverlay.show(
          context,
          title: 'REFERRAL BONUS UNLOCKED!',
          description: reward.title,
          xpGained: amount,
          icon: Icons.card_giftcard_rounded,
        );
        break;

      case RewardType.friendChallenge:
        final amount = reward.data is Map ? (reward.data['amount'] as int? ?? 500) : 500;
        await RewardCelebrationOverlay.show(
          context,
          title: 'CHALLENGE VICTORY UNLOCKED!',
          description: reward.title,
          xpGained: amount,
          icon: Icons.emoji_events_rounded,
        );
        break;
    }
  }

  /// Show celebration modal when a Weekly Challenge is completed
  static Future<void> _showWeeklyChallengeDialog(
    BuildContext context,
    WeeklyChallenge challenge,
  ) async {
    final isDark = context.isDarkMode;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1C22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryContainer,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColors.primaryContainer,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WEEKLY CHALLENGE COMPLETE!',
                textAlign: TextAlign.center,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                challenge.title,
                textAlign: TextAlign.center,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                challenge.description,
                textAlign: TextAlign.center,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primaryContainer, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '+${challenge.xpReward} XP REWARD',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton.primary(
                label: 'CLAIM REWARD',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
