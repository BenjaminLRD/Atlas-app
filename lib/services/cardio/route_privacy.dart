import '../../models/cardio_route.dart';

/// How a route is hidden before it is shared in Community.
enum RoutePrivacyMode {
  /// Hide the area around where the activity started and ended (200 m).
  hide200('Hide start and end (200 m)', 200),

  /// A wider hidden area (500 m), better for a quiet street or a small town.
  hide500('Hide start and end (500 m)', 500),

  /// Share the full route as recorded.
  none('Share the full route', 0),

  /// Share the figures but no map at all.
  noRoute('Don\'t share a route', -1);

  final String label;
  final int radiusM;
  const RoutePrivacyMode(this.label, this.radiusM);

  /// A plain sentence for the share screen.
  String get explanation => switch (this) {
    RoutePrivacyMode.hide200 =>
      'Anyone who can see the post will not see the first and last stretch '
          'of your route, about 200 m around where you started and finished.',
    RoutePrivacyMode.hide500 =>
      'The first and last stretch of your route, about 500 m around where '
          'you started and finished, is left out.',
    RoutePrivacyMode.none =>
      'The whole route is shared, including where you started and finished. '
          'If that is your home, others can see it.',
    RoutePrivacyMode.noRoute =>
      'Only distance, time and pace are shared. No map is shown.',
  };

  static RoutePrivacyMode fromName(String? name) =>
      RoutePrivacyMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => RoutePrivacyMode.hide200,
      );
}

/// What was done to a route, for the share preview and the post.
class MaskedRoute {
  /// The route that may be shared, or empty when none can be.
  final List<RoutePoint> route;

  /// True when part of the route was left out.
  final bool masked;

  /// True when a route exists but was too short to hide safely, so none is
  /// shared rather than a revealing one.
  final bool tooShortToHide;

  const MaskedRoute({
    required this.route,
    required this.masked,
    this.tooShortToHide = false,
  });

  bool get hasRoute => route.length >= 2;
}

/// Hides the places a route starts and ends, before it is shared.
///
/// How it protects:
/// * every point within the hidden radius of the start or of the finish is
///   removed, wherever along the route it is, so a loop that passes the front
///   door again halfway through does not give it away;
/// * of what is left, the longest unbroken stretch is kept, so the shared line
///   never jumps across a gap;
/// * the radius differs a little from one activity to the next (up to 25%
///   wider, chosen from the activity itself), so several posts from the same
///   door cannot be intersected to find it;
/// * when the route is too short to hide safely, no route is shared instead of
///   a revealing one.
///
/// It does not know other places you may want hidden, such as work or a
/// friend's house. Choose "Don't share a route" for those activities.
///
/// The athlete's own saved route is never changed: this works on a copy.
class RoutePrivacy {
  const RoutePrivacy._();

  /// The shortest stretch worth showing after masking.
  static const int minPoints = 3;
  static const double minLengthM = 150;

  static double radiusFor(RoutePrivacyMode mode, int seed) {
    final base = mode.radiusM.toDouble();
    if (base <= 0) return 0;
    final jitter = ((seed.abs() * 2654435761) % 1000) / 1000; // 0 to 0.999
    return base * (1 + 0.25 * jitter);
  }

  /// [seed] should be stable for one activity, for example its start time.
  static MaskedRoute apply(
    List<RoutePoint> route,
    RoutePrivacyMode mode, {
    required int seed,
  }) {
    if (mode == RoutePrivacyMode.noRoute || route.length < 2) {
      return const MaskedRoute(route: [], masked: true);
    }
    if (mode == RoutePrivacyMode.none) {
      return MaskedRoute(route: List.of(route), masked: false);
    }
    final r = radiusFor(mode, seed);
    final s = route.first;
    final e = route.last;

    final runs = <List<RoutePoint>>[];
    var cur = <RoutePoint>[];
    for (final p in route) {
      final hidden =
          Geo.distanceM(s.lat, s.lng, p.lat, p.lng) < r ||
          Geo.distanceM(e.lat, e.lng, p.lat, p.lng) < r;
      if (hidden) {
        if (cur.isNotEmpty) runs.add(cur);
        cur = <RoutePoint>[];
      } else {
        cur.add(p);
      }
    }
    if (cur.isNotEmpty) runs.add(cur);

    List<RoutePoint> best = const [];
    var bestLen = 0.0;
    for (final run in runs) {
      final len = Geo.routeLengthM(run);
      if (run.length >= minPoints && len > bestLen) {
        best = run;
        bestLen = len;
      }
    }
    if (best.length < minPoints || bestLen < minLengthM) {
      return const MaskedRoute(route: [], masked: true, tooShortToHide: true);
    }
    return MaskedRoute(route: best, masked: true);
  }
}
