import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/activity_post.dart';
import '../models/activity_record.dart';
import '../models/cardio_activity_data.dart';
import '../models/cardio_route.dart';
import '../services/cardio/cardio_tracker.dart';
import '../services/community/sample_community.dart';
import '../widgets/cardio/cardio_stats.dart';
import '../widgets/cardio/route_map_view.dart';
import 'cardio_activity_detail_screen.dart';

/// One run or ride in the history list.
class CardioHistoryItem {
  final String id;
  final CardioActivityData data;
  final bool isSample;
  const CardioHistoryItem({
    required this.id,
    required this.data,
    this.isSample = false,
  });
}

/// Builds the history from saved sessions. Pure, so it can be tested alone.
class CardioHistory {
  const CardioHistory._();

  /// Saved runs and rides, newest first, each id once. Sessions that are not
  /// GPS runs or rides (rowing, conditioning) and unfinished ones are left
  /// out; strength workouts are a separate history and are not touched.
  static List<CardioHistoryItem> fromSessions(List<CardioSession> sessions) {
    final seen = <String>{};
    final list = <CardioSession>[
      for (final s in sessions)
        if (s.kind != null && s.isCompleted && seen.add(s.id)) s,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
    return [
      for (final s in list)
        CardioHistoryItem(id: s.id, data: CardioActivityData.fromSession(s)),
    ];
  }

  /// The labelled sample activities shown in Showcase Mode.
  static List<CardioHistoryItem> sample() {
    final items = <CardioHistoryItem>[];
    for (final ActivityPost p in SampleCommunity.posts()) {
      if (p.type != ActivityPostType.cardio) continue;
      final d = CardioActivityData.fromPost(p);
      if (d != null) {
        items.add(CardioHistoryItem(id: p.id, data: d, isSample: true));
      }
    }
    return items;
  }

  static List<CardioHistoryItem> filter(
    List<CardioHistoryItem> all,
    CardioKind? kind,
  ) => kind == null
      ? all
      : [
          for (final i in all)
            if (i.data.kind == kind) i,
        ];
}

/// Previous runs and rides with a route preview, the main figures and a filter
/// between running and cycling. Tapping one opens the full activity.
class CardioHistoryScreen extends StatefulWidget {
  const CardioHistoryScreen({super.key, this.sessions, this.showcase});

  /// Injected by tests; defaults to the saved sessions.
  final List<CardioSession>? sessions;
  final bool? showcase;

  @override
  State<CardioHistoryScreen> createState() => _CardioHistoryScreenState();
}

class _CardioHistoryScreenState extends State<CardioHistoryScreen> {
  CardioKind? _filter;

  bool get _showcase => widget.showcase ?? LocalStorage.isShowcaseModeEnabled();

  List<CardioHistoryItem> get _all => _showcase
      // Showcase never reads the athlete's own sessions.
      ? CardioHistory.sample()
      : CardioHistory.fromSessions(
          widget.sessions ?? LocalStorage.getCardioSessions(),
        );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final items = CardioHistory.filter(all, _filter);
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appTextPrimary),
        title: Text(
          'Cardio history',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('All', null),
                    const SizedBox(width: 8),
                    _chip('Running', CardioKind.running),
                    const SizedBox(width: 8),
                    _chip('Cycling', CardioKind.cycling),
                  ],
                ),
              ),
            ),
            if (_showcase)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'SAMPLE ACTIVITIES: Showcase Mode shows demonstration runs '
                  'and rides, not your own.',
                  key: const Key('history_sample_note'),
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          all.isEmpty
                              ? 'No runs or rides yet. Record one from Cardio '
                                    '& Activity and it will appear here.'
                              : 'No ${_filter!.label.toLowerCase()} activities '
                                    'yet.',
                          key: const Key('history_empty'),
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 13,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _Tile(item: items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, CardioKind? kind) {
    final selected = _filter == kind;
    return ChoiceChip(
      key: Key('hist_filter_${kind?.key ?? 'all'}'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = kind),
      selectedColor: AppColors.primary,
      backgroundColor: context.appSurfaceElevated,
      labelStyle: TextStyle(
        color: selected ? Colors.black : context.appTextPrimary,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});

  final CardioHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final d = item.data;
    final kind = d.kind;
    final rate = kind.isRunning
        ? CardioFormat.pace(d.avgPaceSecPerKm)
        : CardioFormat.speed(d.avgSpeedKmh);
    final rateText = rate == '–'
        ? '–'
        : '$rate ${kind.isRunning ? '/km' : 'km/h'}';
    final parts = <String>[
      d.distanceKm == null
          ? '–'
          : '${CardioFormat.distanceKm(d.distanceKm!)} km',
      d.durationSeconds == null
          ? '–'
          : CardioFormat.duration(d.durationSeconds!),
      rateText,
      if (d.calories != null)
        '${CardioFormat.calories(d.calories)} kcal${d.caloriesEstimated ? ' (est.)' : ''}',
    ];
    return InkWell(
      key: Key('history_${item.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => CardioActivityDetailScreen.open(context, d),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appOutlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: d.route.length >= 2
                  ? RouteMapView(
                      key: Key('history_route_${item.id}'),
                      route: d.route,
                      height: 84,
                      borderRadius: 12,
                      showEnd: true,
                    )
                  : Container(
                      key: Key('history_noroute_${item.id}'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        cardioIcon(kind),
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cardioIcon(kind),
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kind.label,
                          key: Key('history_kind_${item.id}'),
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      if (item.isSample)
                        Text(
                          'SAMPLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: context.appTextSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEE d MMM y, HH:mm').format(d.date),
                    key: Key('history_date_${item.id}'),
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    parts.join('  ·  '),
                    key: Key('history_stats_${item.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
