import 'dart:convert';
import 'dart:math' as math;

/// One place the athlete chose on the map: a stop to head for. It is a plan,
/// not something the GPS recorded, and it never changes the recorded route.
class Waypoint {
  final String id;
  final double lat;
  final double lng;

  const Waypoint({required this.id, required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'id': id, 'lat': lat, 'lng': lng};

  static Waypoint? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (id is! String || lat is! num || lng is! num) return null;
    if (!WaypointPlan.isValidCoordinate(lat.toDouble(), lng.toDouble())) {
      return null;
    }
    return Waypoint(id: id, lat: lat.toDouble(), lng: lng.toDouble());
  }
}

/// Why a stop could not be added.
enum WaypointProblem {
  invalidLocation,
  tooMany,
  tooClose;

  String get message {
    switch (this) {
      case WaypointProblem.invalidLocation:
        return 'That is not a valid place on the map.';
      case WaypointProblem.tooMany:
        return 'You can plan up to ${WaypointPlan.maxStops} stops.';
      case WaypointProblem.tooClose:
        return 'That is too close to the previous stop.';
    }
  }
}

/// Result of trying to add a stop.
class WaypointAddResult {
  final Waypoint? added;
  final WaypointProblem? problem;
  const WaypointAddResult.ok(Waypoint this.added) : problem = null;
  const WaypointAddResult.rejected(WaypointProblem this.problem) : added = null;
  bool get ok => added != null;
}

/// The ordered stops the athlete plans for a run or ride.
///
/// The last stop is the destination; the ones before it are waypoints in
/// order. Distances are straight lines between stops (great-circle), not a
/// street route: Atlas has no routing service, so no turn-by-turn guidance is
/// offered or implied.
class WaypointPlan {
  static const int maxStops = 10;

  /// Stops closer than this to the previous one are refused as accidental
  /// double taps.
  static const double minSeparationM = 15;

  final List<Waypoint> _stops;
  int _nextId;

  WaypointPlan({List<Waypoint>? stops})
    : _stops = [...?stops],
      _nextId = (stops?.length ?? 0) + 1;

  List<Waypoint> get stops => List.unmodifiable(_stops);
  int get length => _stops.length;
  bool get isEmpty => _stops.isEmpty;
  Waypoint? get destination => _stops.isEmpty ? null : _stops.last;

  static bool isValidCoordinate(double lat, double lng) =>
      !lat.isNaN &&
      !lng.isNaN &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  /// Adds a stop at the end (it becomes the destination).
  WaypointAddResult add(double lat, double lng) {
    if (!isValidCoordinate(lat, lng)) {
      return const WaypointAddResult.rejected(WaypointProblem.invalidLocation);
    }
    if (_stops.length >= maxStops) {
      return const WaypointAddResult.rejected(WaypointProblem.tooMany);
    }
    if (_stops.isNotEmpty &&
        distanceM(_stops.last.lat, _stops.last.lng, lat, lng) <
            minSeparationM) {
      return const WaypointAddResult.rejected(WaypointProblem.tooClose);
    }
    final w = Waypoint(id: 'wp_${_nextId++}', lat: lat, lng: lng);
    _stops.add(w);
    return WaypointAddResult.ok(w);
  }

  void remove(String id) => _stops.removeWhere((w) => w.id == id);

  /// Moves a stop. [newIndex] is the stop's final position, as
  /// `ReorderableListView.onReorderItem` reports it.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _stops.length) return;
    newIndex = newIndex.clamp(0, _stops.length - 1);
    final w = _stops.removeAt(oldIndex);
    _stops.insert(newIndex, w);
  }

  void clear() => _stops.clear();

  /// Straight-line length of each leg between consecutive stops, in metres.
  /// The first entry is the leg from stop 1 to stop 2.
  List<double> get legsM => [
    for (var i = 1; i < _stops.length; i++)
      distanceM(
        _stops[i - 1].lat,
        _stops[i - 1].lng,
        _stops[i].lat,
        _stops[i].lng,
      ),
  ];

  /// Straight-line distance through all the stops, in metres.
  double get totalM => legsM.fold(0.0, (a, b) => a + b);

  /// Straight-line distance from a position to the first stop, or null with no
  /// stops.
  double? distanceToFirstFrom(double lat, double lng) => _stops.isEmpty
      ? null
      : distanceM(lat, lng, _stops.first.lat, _stops.first.lng);

  String encode() => jsonEncode([for (final w in _stops) w.toJson()]);

  factory WaypointPlan.decode(String? raw) {
    if (raw == null || raw.isEmpty) return WaypointPlan();
    try {
      final list = jsonDecode(raw);
      if (list is! List) return WaypointPlan();
      final stops = <Waypoint>[];
      for (final e in list) {
        final w = Waypoint.tryParse(e);
        if (w != null && stops.length < maxStops) stops.add(w);
      }
      final plan = WaypointPlan(stops: stops);
      var maxId = 0;
      for (final w in stops) {
        final n = int.tryParse(w.id.replaceFirst('wp_', '')) ?? 0;
        if (n > maxId) maxId = n;
      }
      plan._nextId = maxId + 1;
      return plan;
    } catch (_) {
      return WaypointPlan();
    }
  }

  /// Great-circle distance in metres.
  static double distanceM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// "640 m" below a kilometre, "3.20 km" above.
  static String formatDistance(double metres) => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(2)} km';
}
