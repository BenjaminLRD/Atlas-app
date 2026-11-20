import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_theme.dart';
import '../../models/cardio_route.dart';
import '../../models/waypoint_plan.dart';
import 'map_glass.dart';
import 'route_map_view.dart';

/// Where map tiles come from.
///
/// The default is the public OpenStreetMap tile server. That is free and needs
/// no key, but its usage policy is for light use: before a wide release,
/// switch to a tile provider you have an agreement with by building with
/// `--dart-define=ATLAS_MAP_TILE_URL=https://.../{z}/{x}/{y}.png` (and the
/// matching `ATLAS_MAP_ATTRIBUTION`). A provider that needs a secret key must
/// be reached through a server of your own, because anything in the app can
/// be read out of it. No key is stored in the app.
class MapConfig {
  const MapConfig._();

  static const String tileUrl = String.fromEnvironment(
    'ATLAS_MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String attribution = String.fromEnvironment(
    'ATLAS_MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );
  static const String attributionUrl = String.fromEnvironment(
    'ATLAS_MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.org/copyright',
  );

  /// Identifies the app to the tile server, as its policy requires.
  static const String userAgent = 'com.atlasfitness.app';

  /// Tile errors tolerated before the map gives up and shows the plain route.
  static const int errorLimit = 6;
}

/// A real street map with the route drawn over it, falling back to the plain
/// route drawing when the tiles cannot load. Recording never depends on it.
///
/// Shows streets, parks and landmarks wherever the map data has them, the
/// route, a start flag, the current position while recording, and supports pan
/// and pinch. After finishing it opens fitted to the whole route.
class GeoMapView extends StatefulWidget {
  const GeoMapView({
    super.key,
    required this.route,
    this.current,
    this.height = 220,
    this.interactive = true,
    this.isSample = false,
    this.follow = false,
    this.borderRadius = 16,
    this.emptyMessage = 'No GPS route was recorded',
    this.tileProvider,
    this.waypoints = const [],
    this.onTap,
    this.editingHint,
    this.topLeft,
    this.bottomLeft,
  });

  final List<RoutePoint> route;

  /// Live position, drawn over the route while recording.
  final RoutePoint? current;
  final double height;
  final bool interactive;
  final bool isSample;

  /// Keeps the map centred on [current] until the athlete moves the map.
  final bool follow;
  final double borderRadius;
  final String emptyMessage;

  /// Replaces the network tiles. For tests.
  final TileProvider? tileProvider;

  /// The stops the athlete planned, in order (the last is the destination).
  /// They are drawn as their own markers and a dashed line; they are never
  /// part of [route], which is only what the GPS recorded.
  final List<Waypoint> waypoints;

  /// Called with the tapped place. Set only while the athlete is adding stops.
  final void Function(LatLng point)? onTap;

  /// Shown on the map while [onTap] is set, such as "Tap the map to add a stop".
  final String? editingHint;

  /// Floating controls drawn over the map corners.
  final Widget? topLeft;
  final Widget? bottomLeft;

  @override
  State<GeoMapView> createState() => _GeoMapViewState();
}

class _GeoMapViewState extends State<GeoMapView> {
  final MapController _controller = MapController();
  int _tileErrors = 0;
  bool _failed = false;
  bool _following = true;
  bool _ready = false;

  /// Under `flutter test` there is no network; unless a tile provider is
  /// injected the plain route is shown.
  bool get _tilesAllowed =>
      widget.tileProvider != null ||
      !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didUpdateWidget(covariant GeoMapView old) {
    super.didUpdateWidget(old);
    final c = widget.current;
    if (widget.follow && _following && _ready && !_failed && c != null) {
      try {
        _controller.move(LatLng(c.lat, c.lng), _controller.camera.zoom);
      } catch (_) {}
    }
  }

  void _onTileError() {
    if (_failed || !mounted) return;
    _tileErrors++;
    if (_tileErrors >= MapConfig.errorLimit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _failed = true);
      });
    }
  }

  /// Atlas look for the map tiles. In the dark theme the standard tiles are
  /// inverted and toned to charcoal with a faint green cast: land is dark,
  /// road casings and labels stay lighter and readable. The light theme keeps
  /// the tiles as they are. A colour filter on each tile costs very little.
  static const ColorFilter _atlasDarkTiles = ColorFilter.matrix(<double>[
    -0.1573, -0.5292, -0.0534, 0, 200.7, //
    -0.1743, -0.5865, -0.0592, 0, 225.1, //
    -0.1616, -0.5436, -0.0549, 0, 207.8, //
    0, 0, 0, 1, 0,
  ]);

  Widget _tile(BuildContext context, Widget tile, TileImage image) {
    if (!context.isDarkMode) return tile;
    return ColorFiltered(colorFilter: _atlasDarkTiles, child: tile);
  }

  MapOptions _options(List<LatLng> pts) {
    final flags = widget.interactive
        ? InteractiveFlag.all
        : InteractiveFlag.none;
    void onTap(TapPosition _, LatLng at) => widget.onTap?.call(at);
    void moved(MapCamera camera, bool hasGesture) {
      if (hasGesture) _following = false;
    }

    if (pts.length >= 2) {
      return MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.all(36),
          maxZoom: 17,
        ),
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(flags: flags),
        onMapReady: () => _ready = true,
        onPositionChanged: moved,
        onTap: widget.onTap == null ? null : onTap,
      );
    }
    return MapOptions(
      initialCenter: pts.first,
      initialZoom: 16,
      minZoom: 3,
      maxZoom: 19,
      interactionOptions: InteractionOptions(flags: flags),
      onMapReady: () => _ready = true,
      onPositionChanged: moved,
      onTap: widget.onTap == null ? null : onTap,
    );
  }

  Widget _plain({String? note}) {
    return Stack(
      children: [
        RouteMapView(
          route: widget.route,
          current: widget.current,
          height: widget.height,
          interactive: widget.interactive,
          isSample: widget.isSample,
          borderRadius: widget.borderRadius,
          emptyMessage: widget.emptyMessage,
        ),
        if (widget.topLeft != null)
          Positioned(left: 8, top: 8, child: widget.topLeft!),
        if (widget.bottomLeft != null)
          Positioned(left: 8, bottom: 8, child: widget.bottomLeft!),
        if (note != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: MapGlass(
              key: const Key('map_fallback_note'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              radius: 10,
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: const Key('map_retry'),
                    onTap: () => setState(() {
                      _tileErrors = 0;
                      _failed = false;
                    }),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = <LatLng>[
      for (final p in widget.route) LatLng(p.lat, p.lng),
      if (widget.current != null)
        LatLng(widget.current!.lat, widget.current!.lng),
      for (final w in widget.waypoints) LatLng(w.lat, w.lng),
    ];
    if (pts.isEmpty) return _plain();
    if (!_tilesAllowed) return _plain();
    if (_failed) {
      return _plain(note: 'Map unavailable. Showing your route only.');
    }

    final start = widget.route.isEmpty ? null : widget.route.first;
    final end =
        widget.current ?? (widget.route.length >= 2 ? widget.route.last : null);

    final options = _options(pts);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              key: const Key('geo_map'),
              mapController: _controller,
              options: options,
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgent,
                  tileProvider: widget.tileProvider,
                  maxNativeZoom: 19,
                  tileBuilder: _tile,
                  errorTileCallback: (tile, error, stack) => _onTileError(),
                ),
                if (widget.route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          for (final p in widget.route) LatLng(p.lat, p.lng),
                        ],
                        strokeWidth: 5,
                        color: context.appPrimary,
                        borderStrokeWidth: 2.5,
                        borderColor: context.isDarkMode
                            ? const Color(0xE60B0F0E)
                            : Colors.white,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),
                if (widget.waypoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          if (start != null) LatLng(start.lat, start.lng),
                          for (final w in widget.waypoints)
                            LatLng(w.lat, w.lng),
                        ],
                        strokeWidth: 3,
                        color: context.appPrimary.withValues(alpha: 0.85),
                        pattern: StrokePattern.dashed(segments: [9, 7]),
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < widget.waypoints.length; i++)
                      Marker(
                        point: LatLng(
                          widget.waypoints[i].lat,
                          widget.waypoints[i].lng,
                        ),
                        width: 30,
                        height: 30,
                        child: _StopMarker(
                          key: Key(
                            i == widget.waypoints.length - 1
                                ? 'destination_marker'
                                : 'waypoint_marker_${i + 1}',
                          ),
                          number: i + 1,
                          destination: i == widget.waypoints.length - 1,
                        ),
                      ),
                    if (start != null)
                      Marker(
                        point: LatLng(start.lat, start.lng),
                        width: 28,
                        height: 28,
                        child: const _FlagMarker(),
                      ),
                    if (end != null)
                      Marker(
                        point: LatLng(end.lat, end.lng),
                        width: 26,
                        height: 26,
                        child: _DotMarker(live: widget.current != null),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  attributions: [TextSourceAttribution(MapConfig.attribution)],
                ),
              ],
            ),
            if (widget.isSample)
              Positioned(
                left: 8,
                top: 8,
                child: MapGlass(
                  key: const Key('sample_route_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  radius: 6,
                  child: const Text(
                    'SAMPLE ROUTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            if (widget.follow && !_following)
              Positioned(
                right: 8,
                top: 8,
                child: MapGlassButton(
                  key: const Key('map_recenter'),
                  icon: Icons.my_location_rounded,
                  tooltip: 'Centre on my position',
                  onPressed: () {
                    final c = widget.current;
                    if (c == null) return;
                    setState(() => _following = true);
                    try {
                      _controller.move(LatLng(c.lat, c.lng), 16);
                    } catch (_) {}
                  },
                ),
              ),
            if (widget.topLeft != null)
              Positioned(left: 8, top: 8, child: widget.topLeft!),
            if (widget.bottomLeft != null)
              Positioned(left: 8, bottom: 8, child: widget.bottomLeft!),
            if (widget.onTap != null)
              IgnorePointer(
                child: DecoratedBox(
                  key: const Key('map_editing_frame'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.appPrimary.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                ),
              ),
            if (widget.onTap != null && widget.editingHint != null)
              Positioned(
                left: 56,
                right: 56,
                top: 12,
                child: IgnorePointer(
                  child: Center(
                    child: MapGlass(
                      key: const Key('map_editing_hint'),
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        widget.editingHint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlagMarker extends StatelessWidget {
  const _FlagMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111418),
        border: Border.all(color: context.appPrimary, width: 2),
      ),
      child: Icon(Icons.flag_rounded, size: 15, color: context.appPrimary),
    );
  }
}

/// A planned stop: a numbered charcoal disc with an emerald ring, or, for the
/// last stop, an emerald disc with a finish flag.
class _StopMarker extends StatelessWidget {
  const _StopMarker({
    super.key,
    required this.number,
    required this.destination,
  });

  final int number;
  final bool destination;

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    return Semantics(
      label: destination ? 'Destination' : 'Stop $number',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: destination ? accent : const Color(0xFF111418),
          border: Border.all(
            color: destination ? const Color(0xFF111418) : accent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: destination
            ? const Icon(
                Icons.sports_score_rounded,
                size: 16,
                color: Color(0xFF111418),
              )
            : Text(
                '$number',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _DotMarker extends StatelessWidget {
  const _DotMarker({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        border: Border.all(color: const Color(0xFF111418), width: 3),
        boxShadow: live
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
    );
  }
}
