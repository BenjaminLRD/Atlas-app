import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/activity_post.dart';
import '../../models/cardio_activity_data.dart';
import '../../screens/cardio_activity_detail_screen.dart';
import '../../services/cardio/cardio_tracker.dart';
import '../cardio/cardio_stats.dart';
import '../cardio/geo_map_view.dart';
import '../cardio/route_map_view.dart';

/// Community card for a completed run or ride: the recorded route beside the
/// distance, time and pace or speed.
///
/// In the feed ([large] false) tapping the route opens the full activity;
/// tapping anywhere else falls through to the post page. On the post page
/// ([large] true) the route is larger and all statistics are shown.
class CardioPostCard extends StatelessWidget {
  const CardioPostCard({super.key, required this.post, this.large = false});

  final ActivityPost post;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final data = CardioActivityData.fromPost(post);
    if (data == null) return const SizedBox.shrink();
    final kind = data.kind;
    const accent = AppColors.primary;
    void openActivity() => CardioActivityDetailScreen.open(context, data);

    final rate = kind.isRunning
        ? CardioFormat.pace(data.avgPaceSecPerKm)
        : CardioFormat.speed(data.avgSpeedKmh);
    final rateUnit = kind.isRunning ? '/km' : 'km/h';

    return Container(
      key: Key('cardio_card_${post.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(cardioIcon(kind), size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kind.label.toUpperCase(),
                  key: const Key('cardio_kind'),
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              if (data.isSample)
                Flexible(child: Text(
                  'SAMPLE ACTIVITY',
                  key: const Key('cardio_sample_label'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                )),
            ],
          ),
          const SizedBox(height: 10),
          if (large) ...[
            GeoMapView(
              key: const Key('cardio_route_large'),
              route: data.route,
              height: 260,
              interactive: true,
              isSample: data.isSample,
            ),
            const SizedBox(height: 14),
            CardioDistanceHero(distanceKm: data.distanceKm),
            const SizedBox(height: 12),
            CardioStatsPanel(data: data),
          ] else
            SizedBox(
              height: 156,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      key: const Key('cardio_route_preview'),
                      behavior: HitTestBehavior.opaque,
                      onTap: openActivity,
                      child: RouteMapView(
                        route: data.route,
                        height: 156,
                        isSample: data.isSample,
                        borderRadius: 14,
                        emptyMessage: data.routeShared
                            ? 'No GPS route'
                            : 'Route not shared',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 156,
                      child: Column(
                        children: [
                          _MiniStat(
                            key: const Key('card_distance'),
                            value: data.distanceKm == null
                                ? '–'
                                : CardioFormat.distanceKm(data.distanceKm!),
                            unit: 'km',
                            label: 'Distance',
                          ),
                          const SizedBox(height: 6),
                          _MiniStat(
                            key: const Key('card_duration'),
                            value: data.durationSeconds == null
                                ? '–'
                                : CardioFormat.duration(data.durationSeconds!),
                            label: 'Duration',
                          ),
                          const SizedBox(height: 6),
                          _MiniStat(
                            key: const Key('card_rate'),
                            value: rate,
                            unit: rate == '–' ? null : rateUnit,
                            label: kind.isRunning ? 'Pace' : 'Speed',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!large && data.calories != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${CardioFormat.calories(data.calories)} kcal'
                    '${data.caloriesEstimated ? ' (est.)' : ''}',
                    key: const Key('card_calories'),
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    super.key,
    required this.value,
    required this.label,
    this.unit,
  });

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appOutlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                unit == null ? value : '$value $unit',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            FittedBox(child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(
                fontSize: 10,
                color: context.appTextSecondary,
              ),
            )),
          ],
        ),
      ),
    );
  }
}
