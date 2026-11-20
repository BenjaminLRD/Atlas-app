import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../providers/fitness_provider.dart';
import '../../services/ranked/rank_ladder.dart';
import '../../services/ranked/ranked_catalog.dart';
import '../../services/ranked/ranked_evaluator.dart';
import '../../services/ranked/ranked_progress_store.dart';
import '../../services/ranked/ranked_service.dart';
import '../common/app_card.dart';

/// Rank, stats and milestones for Ranked mode.
class RankedProgressPanel extends StatelessWidget {
  const RankedProgressPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RankedService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final catalog = service.catalog;
        final local = service.localEvaluation;
        final snapshot = service.snapshot;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RankCard(snapshot: snapshot, busy: service.isBusy),
            if (service.error != null) ...[
              const SizedBox(height: 8),
              Text(
                service.error!,
                style: AppTheme.bodySm.copyWith(color: AppColors.error),
              ),
            ],
            if (local != null && !local.hasBodyweight) ...[
              const SizedBox(height: 12),
              _Notice(
                text:
                    'Add your body weight in your profile to unlock Strength milestones.',
              ),
            ],
            const SizedBox(height: 16),
            if (catalog != null && local != null)
              for (final stat in catalog.stats) ...[
                _StatCard(
                  stat: stat,
                  catalog: catalog,
                  local: local,
                  snapshot: snapshot,
                  gender: service.gender,
                  canVerify: service.canVerify,
                ),
                const SizedBox(height: 12),
              ]
            else if (service.isBusy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class _RankCard extends StatelessWidget {
  final RankedSnapshot snapshot;
  final bool busy;

  const _RankCard({required this.snapshot, required this.busy});

  @override
  Widget build(BuildContext context) {
    final position = snapshot.position;
    final next = position.isRanked ? position.next : RankLadder.fromPoints(1);
    final top = RankLadder.divisionCount;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RANKED',
                  style: AppTheme.labelCaps.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Flexible(
                  child: Text(
                    snapshot.verified ? 'Verified' : 'Estimate, not verified',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: snapshot.verified
                          ? AppColors.primary
                          : context.appTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            position.title,
            style: AppTheme.headlineLg.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'Top division reached.'
                : position.isRanked
                ? 'Next: ${next.title}. Every milestone level moves you up one division.'
                : 'Hit your first milestone to reach Bronze III.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (snapshot.points / top).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.appSurfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${snapshot.points} of $top points to Champion I',
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final RankedStat stat;
  final RankedCatalog catalog;
  final RankedEvaluation local;
  final RankedSnapshot snapshot;
  final String gender;
  final bool canVerify;

  const _StatCard({
    required this.stat,
    required this.catalog,
    required this.local,
    required this.snapshot,
    required this.gender,
    required this.canVerify,
  });

  @override
  Widget build(BuildContext context) {
    final verifiedLevel = snapshot.statLevels[stat.id] ?? 0;
    final level = snapshot.verified
        ? verifiedLevel
        : (local.statLevels[stat.id] ?? 0);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.name,
                  style: AppTheme.headlineSm.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Text(
                'Level $level / ${catalog.levelsPerStat}',
                style: AppTheme.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stat.description,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final m in stat.milestones)
            _MilestoneRow(
              progress: local.milestones[m.id]!,
              catalog: catalog,
              snapshot: snapshot,
              gender: gender,
              canVerify: canVerify,
            ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final MilestoneProgress progress;
  final RankedCatalog catalog;
  final RankedSnapshot snapshot;
  final String gender;
  final bool canVerify;

  const _MilestoneRow({
    required this.progress,
    required this.catalog,
    required this.snapshot,
    required this.gender,
    required this.canVerify,
  });

  static String formatValue(MilestoneMeasure measure, double value) {
    switch (measure) {
      case MilestoneMeasure.bodyweightMultiple:
        return '${value.toStringAsFixed(2)}× body weight';
      case MilestoneMeasure.maxReps:
        return '${value.round()} reps';
      case MilestoneMeasure.time5kMinutes:
        final seconds = (value * 60).round();
        return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      case MilestoneMeasure.workoutsInWindow:
        return '${value.round()} workouts';
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = progress.milestone;
    final best = progress.best;
    final nextTarget = progress.nextTarget(gender);

    // A level the device reached that still needs proof on the server.
    RankedClaim? videoClaim;
    for (var l = progress.level; l >= catalog.videoRequiredFromLevel; l--) {
      final claim = snapshot.claimFor(m.id, l);
      if (claim != null && !claim.isApproved) {
        videoClaim = claim;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.title,
                  style: AppTheme.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Text(
                best == null ? 'No data yet' : formatValue(m.measure, best),
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            nextTarget == null
                ? 'All 5 levels reached.'
                : 'Level ${progress.level + 1} at ${formatValue(m.measure, nextTarget)}'
                      '${catalog.needsVideo(m, progress.level + 1) ? ' (video proof)' : ''}',
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          if (videoClaim != null && canVerify)
            _ProofAction(milestone: m, claim: videoClaim),
        ],
      ),
    );
  }
}

class _ProofAction extends StatelessWidget {
  final RankedMilestone milestone;
  final RankedClaim claim;

  const _ProofAction({required this.milestone, required this.claim});

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;
    try {
      await RankedService.instance.submitProof(
        milestoneId: milestone.id,
        level: claim.level,
        video: File(picked.path),
      );
      await FitnessProvider.instance.refreshRanked();
      messenger.showSnackBar(
        const SnackBar(content: Text('Video sent for review.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (claim.isPendingReview) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Level ${claim.level}: video under review.',
          style: AppTheme.bodySm.copyWith(
            fontSize: 12,
            color: AppColors.primary,
          ),
        ),
      );
    }
    final rejected = claim.status == 'rejected';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rejected
                  ? 'Level ${claim.level} video not accepted${claim.reviewerNote == null ? '' : ': ${claim.reviewerNote}'}'
                  : 'Level ${claim.level} needs a video of the lift.',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                color: rejected ? AppColors.error : context.appTextSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _submit(context),
            child: Text(rejected ? 'Send another' : 'Submit video'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
      ),
    );
  }
}

/// Verified leaderboard from the server.
class RankedLeaderboardCard extends StatelessWidget {
  const RankedLeaderboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RankedService.instance;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leaderboard',
            style: AppTheme.headlineSm.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: 10),
          if (!service.canVerify)
            Text(
              'The leaderboard needs an account. Ranks here are estimates.',
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            )
          else
            FutureBuilder<List<RankedLeaderboardRow>>(
              future: service.leaderboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows = snapshot.data ?? const [];
                if (snapshot.hasError || rows.isEmpty) {
                  return Text(
                    snapshot.hasError
                        ? 'Could not load the leaderboard.'
                        : 'Sign in and hit a milestone to appear here.',
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          '${i + 1}',
                          style: AppTheme.bodySm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        title: Text(
                          rows[i].displayName,
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextPrimary,
                          ),
                        ),
                        trailing: Text(
                          RankLadder.fromPoints(rows[i].points).title,
                          style: AppTheme.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
