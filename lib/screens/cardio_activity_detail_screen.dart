import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/cardio_activity_data.dart';
import '../widgets/cardio/cardio_stats.dart';
import '../widgets/cardio/geo_map_view.dart';

/// Full view of one run or ride: a large route, the distance and every
/// statistic that was recorded. Used for the athlete's own saved sessions and
/// for activities shared in Community, including sample ones.
class CardioActivityDetailScreen extends StatelessWidget {
  const CardioActivityDetailScreen({super.key, required this.data});

  final CardioActivityData data;

  static Future<void> open(BuildContext context, CardioActivityData data) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardioActivityDetailScreen(data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = data.kind;
    final who = data.athleteName == null ? '' : ' · ${data.athleteName}';
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appTextPrimary),
        title: Text(
          data.title,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(cardioIcon(kind), size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${kind.label} · '
                      '${DateFormat('EEE d MMM, HH:mm').format(data.date)}$who',
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (data.isSample)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'SAMPLE ACTIVITY: the route and figures are demonstration '
                    'data, not a real GPS recording.',
                    key: const Key('detail_sample_note'),
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GeoMapView(
                key: const Key('detail_map'),
                route: data.route,
                height: 320,
                interactive: true,
                isSample: data.isSample,
                emptyMessage: data.routeShared
                    ? 'No GPS route was recorded'
                    : 'The athlete chose not to share the route',
              ),
              if (data.routeMasked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'The start and end of this route are hidden for privacy.',
                    key: const Key('detail_masked_note'),
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              CardioDistanceHero(distanceKm: data.distanceKm),
              const SizedBox(height: 14),
              CardioStatsPanel(data: data),
              if (data.calories != null && data.caloriesEstimated)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Calories are an estimate from body weight and average '
                    'speed, not a measurement.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
