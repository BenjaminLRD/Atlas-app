import 'dart:math' as math;

/// The two outdoor activities that are tracked with GPS.
enum CardioKind {
  running('Running', 'Run', 'running'),
  cycling('Cycling', 'Ride', 'cycling');

  /// Stored as the session category and shown as the activity name.
  final String label;

  /// Short noun for a single outing: "Run" or "Ride".
  final String noun;

  /// Stable key used in post metadata and exercise ids.
  final String key;
  const CardioKind(this.label, this.noun, this.key);

  bool get isRunning => this == CardioKind.running;

  /// Pace (min/km) for running, speed (km/h) for cycling.
  String get primaryRateLabel => isRunning ? 'Pace' : 'Speed';

  static CardioKind? fromKey(String? raw) {
    final v = raw?.toLowerCase();
    if (v == null) return null;
    for (final k in CardioKind.values) {
      if (k.key == v || k.label.toLowerCase() == v) return k;
    }
    return null;
  }
}

/// One recorded GPS position of a route.
class RoutePoint {
  final double lat;
  final double lng;

  /// Milliseconds since the epoch when the fix was taken.
  final int timeMs;

  const RoutePoint(this.lat, this.lng, [this.timeMs = 0]);

  /// Compact `[lat, lng, timeMs]` form, small enough to store and post.
  List<num> toJson() => [lat, lng, timeMs];

  static RoutePoint? tryParse(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final lat = raw[0];
    final lng = raw[1];
    if (lat is! num || lng is! num) return null;
    final la = lat.toDouble();
    final ln = lng.toDouble();
    if (la.isNaN || ln.isNaN || la.abs() > 90 || ln.abs() > 180) return null;
    final t = raw.length > 2 && raw[2] is num ? (raw[2] as num).toInt() : 0;
    return RoutePoint(la, ln, t);
  }

  static List<RoutePoint> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) ?RoutePoint.tryParse(e)];
  }

  static List<List<num>> listToJson(List<RoutePoint> points) => [
    for (final p in points) p.toJson(),
  ];

  @override
  bool operator ==(Object other) =>
      other is RoutePoint &&
      other.lat == lat &&
      other.lng == lng &&
      other.timeMs == timeMs;

  @override
  int get hashCode => Object.hash(lat, lng, timeMs);
}

/// Distance and route helpers. Plain maths, no plugins.
class Geo {
  const Geo._();

  static const double _earthRadiusM = 6371008.8;

  static double _rad(double d) => d * math.pi / 180;

  /// Great-circle distance in metres between two points.
  static double distanceM(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Length of a whole route in metres.
  static double routeLengthM(List<RoutePoint> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += distanceM(
        route[i - 1].lat,
        route[i - 1].lng,
        route[i].lat,
        route[i].lng,
      );
    }
    return total;
  }

  /// Keeps at most [maxPoints] points, always including the first and last,
  /// so a long route stays small enough to store and to post.
  static List<RoutePoint> downsample(List<RoutePoint> route, int maxPoints) {
    if (maxPoints < 2 || route.length <= maxPoints) return route;
    final out = <RoutePoint>[];
    final step = (route.length - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints; i++) {
      out.add(route[(i * step).round().clamp(0, route.length - 1)]);
    }
    return out;
  }
}

/// Privacy helper for routes that are shared.
extension GeoPrivacy on Geo {
  /// Drops the points within [metres] of the start and of the end, so a posted
  /// route does not show where the athlete lives. Returns the route unchanged
  /// when it is too short to trim safely.
  static List<RoutePoint> trimEnds(List<RoutePoint> route, double metres) {
    if (route.length < 4) return route;
    if (Geo.routeLengthM(route) < metres * 4) return route;
    var from = 0;
    final s = route.first;
    while (from < route.length - 1 &&
        Geo.distanceM(s.lat, s.lng, route[from].lat, route[from].lng) <
            metres) {
      from++;
    }
    var to = route.length - 1;
    final e = route.last;
    while (to > from &&
        Geo.distanceM(e.lat, e.lng, route[to].lat, route[to].lng) < metres) {
      to--;
    }
    if (to - from < 2) return route;
    return route.sublist(from, to + 1);
  }
}
