import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/friend_challenge.dart';
import '../../services/friend_challenge_service.dart';
import '../../services/growth_analytics_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';

/// Card widget managing active 1v1 friend challenges and challenge invitations.
class FriendChallengeCard extends StatefulWidget {
  const FriendChallengeCard({super.key});

  @override
  State<FriendChallengeCard> createState() => _FriendChallengeCardState();
}

class _FriendChallengeCardState extends State<FriendChallengeCard> {
  late final FriendChallengeService _challengeService;
  late List<FriendChallenge> _challenges;

  @override
  void initState() {
    super.initState();
    _challengeService = FriendChallengeService.instance;
    _challenges = _challengeService.getChallenges();
  }

  void _refresh() {
    setState(() {
      _challenges = _challengeService.getChallenges();
    });
  }

  void _showCreateChallengeModal() {
    String opponentName = 'Alex Carter';
    ChallengeType selectedType = ChallengeType.volumeShowdown;
    final targetController = TextEditingController(text: '10000');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appOutlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'CREATE 1V1 FRIEND CHALLENGE',
                    style: AppTheme.headlineLg.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),

                  // Challenge Type Selector Chips
                  Text('CHALLENGE TYPE', style: AppTheme.bodySm.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ChallengeType.values.map((t) {
                      final isSel = t == selectedType;
                      return ChoiceChip(
                        label: Text(t.name.replaceAll('Showdown', '').replaceAll('Sprint', '').toUpperCase()),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: AppTheme.bodySm.copyWith(
                          color: isSel ? Colors.white : context.appTextSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                        onSelected: (val) => setModalState(() => selectedType = t),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Target Goal Input
                  Text('TARGET GOAL', style: AppTheme.bodySm.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.bodySm.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'e.g. 10000 kg volume or 7 days streak',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: context.appSurfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 20),

                  AppButton.primary(
                    label: 'SEND CHALLENGE INVITATION',
                    icon: Icons.send_rounded,
                    onPressed: () {
                      final goal = double.tryParse(targetController.text.trim()) ?? 10000.0;
                      _challengeService.createChallenge(
                        opponentId: 'usr_alex',
                        opponentName: opponentName,
                        type: selectedType,
                        title: '1v1 ${selectedType.name.toUpperCase()} SHOWDOWN',
                        targetGoal: goal,
                        xpReward: 500,
                      );

                      GrowthAnalyticsService.instance.trackChallengeJoined();
                      Navigator.pop(context);
                      _refresh();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('1v1 Challenge sent to $opponentName!')),
                      );
                    },
                    isPill: true,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1V1 FRIEND CHALLENGES',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Compete head-to-head with workout buddies',
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: _showCreateChallengeModal,
                icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                tooltip: 'Create Challenge',
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_challenges.isEmpty) ...[
            Text('No active challenges. Tap + to challenge a friend!', style: AppTheme.bodySm.copyWith(fontSize: 11)),
          ] else ...[
            ..._challenges.map((c) => _buildChallengeTile(context, c)),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeTile(BuildContext context, FriendChallenge c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appOutlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.title,
                style: AppTheme.headlineMd.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${c.xpReward} XP',
                  style: AppTheme.bodySm.copyWith(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            '${c.creatorName} vs ${c.opponentName}',
            style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
          ),

          const SizedBox(height: 10),

          // VS Dual Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.creatorName}: ${c.creatorProgress.toInt()}',
                      style: AppTheme.bodySm.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.creatorPercentage,
                        minHeight: 6,
                        backgroundColor: context.appOutlineVariant,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.amber)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${c.opponentName}: ${c.opponentProgress.toInt()}',
                      style: AppTheme.bodySm.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.opponentPercentage,
                        minHeight: 6,
                        backgroundColor: context.appOutlineVariant,
                        color: const Color(0xFFA855F7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (c.isPending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _challengeService.declineChallenge(c.id);
                    _refresh();
                  },
                  child: const Text('DECLINE'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _challengeService.acceptChallenge(c.id);
                    _refresh();
                  },
                  child: const Text('ACCEPT'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
