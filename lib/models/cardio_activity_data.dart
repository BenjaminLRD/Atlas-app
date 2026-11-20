import 'activity_post.dart';
import 'activity_record.dart';
import 'cardio_route.dart';

/// Everything the cardio card and the activity detail screen show, whether it
/// came from a saved session or from a Community post.
///
/// Missing values are null, never zero.
class CardioActivityData {
  final CardioKind kind;
  final String title;
  final DateTime date;
  final double? distanceKm;
  final int? durationSeconds;
  final double? avgSpeedKmh;
  final double? avgPaceSecPerKm;
  final double? calories;
  final bool caloriesEstimated;
  final List<RoutePoint> route;

  /// True for built-in sample activities. Their routes are sample data, never
  /// a real GPS recording.
  final bool isSample;
  final String? athleteName;

  /// True when the shared route has its start and end hidden.
  final bool routeMasked;

  /// False when the athlete chose not to share a route (or it was too short to
  /// hide safely).
  final bool routeShared;

  const CardioActivityData({
    required this.kind,
    required this.title,
    required this.date,
    this.distanceKm,
    this.durationSeconds,
    this.avgSpeedKmh,
    this.avgPaceSecPerKm,
    this.calories,
    this.caloriesEstimated = true,
    this.route = const [],
    this.isSample = false,
    this.athleteName,
    this.routeMasked = false,
    this.routeShared = true,
  });

  /// True when the post metadata describes a running or cycling activity.
  static bool isCardioMetadata(Map<String, dynamic>? m) =>
      CardioKind.fromKey(m?['activity'] as String?) != null;

  factory CardioActivityData.fromSession(CardioSession s) {
    final kind = s.kind ?? CardioKind.running;
    final speed = s.avgSpeedKmh;
    return CardioActivityData(
      kind: kind,
      title: s.exerciseName,
      date: s.startTime,
      distanceKm: s.distanceKm > 0 ? s.distanceKm : null,
      durationSeconds: s.durationSeconds,
      avgSpeedKmh: speed,
      avgPaceSecPerKm: (speed != null && speed >= 1) ? 3600 / speed : null,
      calories: s.caloriesKnown ? s.caloriesBurned : null,
      caloriesEstimated: s.caloriesEstimated,
      route: s.route,
    );
  }

  /// Reads a cardio post. Returns null when the post is not a cardio activity.
  static CardioActivityData? fromPost(ActivityPost post) {
    final m = post.metadata;
    final kind = CardioKind.fromKey(m?['activity'] as String?);
    if (m == null || kind == null) return null;
    double? num_(String k) => (m[k] as num?)?.toDouble();
    final dist = num_('distanceKm');
    final dur = (m['durationSeconds'] as num?)?.toInt();
    var speed = num_('avgSpeedKmh');
    if (speed == null && dist != null && dur != null && dur > 0 && dist > 0) {
      speed = dist / (dur / 3600);
    }
    var pace = num_('avgPaceSecPerKm');
    if (pace == null && speed != null && speed >= 1) pace = 3600 / speed;
    return CardioActivityData(
      kind: kind,
      title: post.title,
      date: post.createdAt,
      distanceKm: dist,
      durationSeconds: dur,
      avgSpeedKmh: speed,
      avgPaceSecPerKm: pace,
      calories: num_('calories'),
      caloriesEstimated: m['caloriesEstimated'] as bool? ?? true,
      route: RoutePoint.listFromJson(m['route']),
      isSample: post.isSample || m['sampleRoute'] == true,
      athleteName: post.userName,
      routeMasked: m['routeMasked'] == true,
      routeShared: m['routeShared'] != false,
    );
  }

  /// The metadata saved with a post made from this activity.
  Map<String, dynamic> toPostMetadata({
    List<RoutePoint>? routeOverride,
    bool routeMasked = false,
    bool routeShared = true,
  }) {
    final r = routeOverride ?? route;
    return {
      'activity': kind.key,
      if (distanceKm != null)
        'distanceKm': double.parse(distanceKm!.toStringAsFixed(3)),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (avgSpeedKmh != null)
        'avgSpeedKmh': double.parse(avgSpeedKmh!.toStringAsFixed(2)),
      if (avgPaceSecPerKm != null) 'avgPaceSecPerKm': avgPaceSecPerKm!.round(),
      if (calories != null) ...{
        'calories': calories!.round(),
        'caloriesEstimated': caloriesEstimated,
      },
      if (routeMasked) 'routeMasked': true,
      if (!routeShared) 'routeShared': false,
      if (r.length >= 2)
        'route': [
          for (final p in r)
            [
              double.parse(p.lat.toStringAsFixed(5)),
              double.parse(p.lng.toStringAsFixed(5)),
            ],
        ],
    };
  }
}
