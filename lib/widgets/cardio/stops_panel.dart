import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/waypoint_plan.dart';

/// Where the athlete manages planned stops: add at their position, reorder,
/// remove, see the distance of each leg, and finish editing.
///
/// Distances are straight lines between stops. Atlas has no routing service,
/// so the panel says so and offers no directions.
class StopsPanel extends StatelessWidget {
  const StopsPanel({
    super.key,
    required this.plan,
    required this.onAddHere,
    required this.onRemove,
    required this.onReorder,
    required this.onClear,
    required this.onDone,
    this.fromLat,
    this.fromLng,
    this.addHereHint,
  });

  final WaypointPlan plan;

  /// Null when there is no usable GPS position to add.
  final VoidCallback? onAddHere;
  final void Function(String id) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onClear;
  final VoidCallback onDone;

  /// The athlete's position, for the distance to the first stop.
  final double? fromLat;
  final double? fromLng;

  /// Why [onAddHere] is unavailable.
  final String? addHereHint;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final legs = plan.legsM;
    final toFirst = (fromLat == null || fromLng == null)
        ? null
        : plan.distanceToFirstFrom(fromLat!, fromLng!);
    return Container(
      key: const Key('stops_panel'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [Colors.white, Colors.white.withValues(alpha: 0.75)],
        ),
        border: Border.all(color: context.appPrimary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.isEmpty
                      ? 'Plan your stops'
                      : 'Planned stops (${plan.length}/${WaypointPlan.maxStops})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              if (!plan.isEmpty)
                TextButton(
                  key: const Key('stops_clear'),
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              const SizedBox(width: 4),
              FilledButton(
                key: const Key('stops_done'),
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(72, 40),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.isEmpty
                ? 'Tap the map to drop a stop, or add your current position. '
                      'The last stop is your destination.'
                : 'Drag to reorder. The last stop is your destination.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('stops_add_here'),
              onPressed: onAddHere,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Add my position'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appPrimary,
                side: BorderSide(
                  color: onAddHere == null
                      ? context.appOutlineVariant
                      : context.appPrimary,
                ),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
          if (onAddHere == null && addHereHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                addHereHint!,
                key: const Key('stops_add_here_hint'),
                style: TextStyle(fontSize: 12, color: context.appTextMuted),
              ),
            ),
          if (!plan.isEmpty) ...[
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: onReorder,
              children: [
                for (var i = 0; i < plan.length; i++)
                  _StopRow(
                    key: ValueKey(plan.stops[i].id),
                    index: i,
                    stop: plan.stops[i],
                    isDestination: i == plan.length - 1,
                    subtitle: i == 0
                        ? (toFirst == null
                              ? 'First stop'
                              : '${WaypointPlan.formatDistance(toFirst)} from you')
                        : '${WaypointPlan.formatDistance(legs[i - 1])} from '
                              'stop $i',
                    onRemove: () => onRemove(plan.stops[i].id),
                  ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.length < 2
                        ? 'Add another stop to see the distance between stops.'
                        : 'Between stops: '
                              '${WaypointPlan.formatDistance(plan.totalM)}',
                    key: const Key('stops_total'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Straight-line distances, not a road route. Atlas does not give '
              'turn-by-turn directions, and stops do not change your recorded '
              'GPS route.',
              key: const Key('stops_disclaimer'),
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: context.appTextMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.index,
    required this.stop,
    required this.isDestination,
    required this.subtitle,
    required this.onRemove,
  });

  final int index;
  final Waypoint stop;
  final bool isDestination;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDestination ? accent : const Color(0xFF111418),
              border: Border.all(color: accent, width: 2),
            ),
            child: isDestination
                ? const Icon(
                    Icons.sports_score_rounded,
                    size: 16,
                    color: Color(0xFF111418),
                  )
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDestination ? 'Destination' : 'Stop ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('stop_remove_${stop.id}'),
            tooltip: 'Remove stop',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            color: context.appTextSecondary,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.drag_handle_rounded,
                key: Key('stop_drag_${stop.id}'),
                color: context.appTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
