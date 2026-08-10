import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/gym_community_event.dart';
import '../../services/community_event_service.dart';

/// Card widget showcasing active Gym Community Events & Collective Fitness Quests.
class CommunityEventCard extends StatefulWidget {
  const CommunityEventCard({super.key});

  @override
  State<CommunityEventCard> createState() => _CommunityEventCardState();
}

class _CommunityEventCardState extends State<CommunityEventCard> {
  late final CommunityEventService _eventService;
  late List<GymCommunityEvent> _events;

  @override
  void initState() {
    super.initState();
    _eventService = CommunityEventService.instance;
    _events = _eventService.getEvents();
  }

  void _refresh() {
    setState(() {
      _events = _eventService.getEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) return const SizedBox.shrink();
    final event = _events.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppGradients.emeraldGlow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [AppShadows.ambientGlow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Badge & Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'GYM COMMUNITY RALLY',
                      style: AppTheme.bodySm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${event.remainingDays} days left',
                    style: AppTheme.bodySm.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title & Description
          Text(
            event.title,
            style: AppTheme.headlineLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.description,
            style: AppTheme.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 14),

          // Progress Ticker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${event.currentProgress.toInt()} / ${event.targetGoal.toInt()} ${event.unitLabel}',
                style: AppTheme.headlineMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(event.progressPercentage * 100).toStringAsFixed(1)}%',
                style: AppTheme.headlineMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Collective Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: event.progressPercentage,
              minHeight: 10,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 14),

          // Participants & Join Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${event.participantCount} Lifters Joined',
                    style: AppTheme.bodySm.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: event.isJoined
                    ? null
                    : () {
                        _eventService.joinEvent(event.id);
                        _refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Joined Gym Community Rally! +1500 XP Goal')),
                        );
                      },
                icon: Icon(
                  event.isJoined ? Icons.check_circle_rounded : Icons.flash_on_rounded,
                  size: 14,
                ),
                label: Text(event.isJoined ? 'PARTICIPATING' : 'JOIN RALLY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: event.isJoined ? Colors.white24 : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w900, fontSize: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
