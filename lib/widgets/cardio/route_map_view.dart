import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/cardio_route.dart';

/// Draws a recorded route on a dark, map-style canvas.
///
/// The line is exactly the GPS points that were recorded: nothing is smoothed
/// into a different shape and nothing is invented. There are no map tiles, so
/// it needs no network, no API key and never sits on a loading spinner.
///
/// With [interactive] the route can be panned and pinched.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.route,
    this.current,
    this.height = 180,
    this.interactive = false,
    this.isSample = false,
    this.borderRadius = 16,
    this.emptyMessage = 'No GPS route was recorded',
    this.showEnd = true,
  });

  final List<RoutePoint> route;

  /// Live position marker, drawn on top of the route while recording.
  final RoutePoint? current;
  final double height;
  final bool interactive;

  /// Marks the route as sample data, never a real recording.
  final bool isSample;
  final double borderRadius;
  final String emptyMessage;

  /// Draws the finish marker at the end of the route.
  final bool showEnd;

  @override
  Widget build(BuildContext context) {
    final points = <RoutePoint>[...route, ?current];
    Widget canvas;
    if (points.isEmpty) {
      canvas = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off_outlined,
                size: 18,
                color: context.appTextSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  emptyMessage,
                  key: const Key('route_empty'),
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      canvas = CustomPaint(
        key: const Key('route_canvas'),
        painter: _RoutePainter(
          route: route,
          current: current,
          line: AppColors.primary,
          dark: context.isDarkMode,
          showEnd: showEnd,
          grid: context.appOutlineVariant,
        ),
        size: Size.infinite,
      );
      if (interactive) {
        canvas = InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: SizedBox.expand(child: canvas),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? const Color(0xFF1B1F23)
              : const Color(0xFFE9EEF0),
          border: Border.all(color: context.appOutlineVariant),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            canvas,
            if (isSample)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  key: const Key('sample_route_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
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
          ],
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.route,
    required this.current,
    required this.line,
    required this.dark,
    required this.showEnd,
    required this.grid,
  });

  final List<RoutePoint> route;
  final RoutePoint? current;
  final Color line;
  final bool dark;
  final bool showEnd;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint street-grid texture so it reads as a map.
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const cell = 28.0;
    for (var x = 0.0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final all = <RoutePoint>[...route, ?current];
    if (all.isEmpty) return;

    var minLat = all.first.lat, maxLat = all.first.lat;
    var minLng = all.first.lng, maxLng = all.first.lng;
    for (final p in all) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // Longitude degrees shrink with latitude; keep the shape true.
    final midLat = (minLat + maxLat) / 2;
    final kx = math.cos(midLat * math.pi / 180);
    var w = (maxLng - minLng) * kx;
    var h = maxLat - minLat;
    // A very short route is not blown up to fill the card: keep a minimum
    // span of about 60 m.
    const minSpan = 0.00055;
    if (w < minSpan) w = minSpan;
    if (h < minSpan) h = minSpan;

    const pad = 28.0;
    final availW = math.max(1.0, size.width - pad * 2);
    final availH = math.max(1.0, size.height - pad * 2);
    final scale = math.min(availW / w, availH / h);
    final cx = (minLng + maxLng) / 2;
    final cy = (minLat + maxLat) / 2;

    Offset project(RoutePoint p) => Offset(
      size.width / 2 + (p.lng - cx) * kx * scale,
      size.height / 2 - (p.lat - cy) * scale,
    );

    if (route.length >= 2) {
      final path = Path()
        ..moveTo(project(route.first).dx, project(route.first).dy);
      for (var i = 1; i < route.length; i++) {
        final o = project(route[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Start waypoint: a flag on a dark disc.
    if (route.isNotEmpty) {
      _flag(canvas, project(route.first));
    }
    // Finish or live position.
    final end = current ?? (showEnd && route.length >= 2 ? route.last : null);
    if (end != null) {
      _dot(canvas, project(end), live: current != null);
    }
  }

  void _flag(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF111418));
    canvas.drawCircle(
      c,
      11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final pole = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6;
    canvas.drawLine(c + const Offset(-2, 5), c + const Offset(-2, -5), pole);
    final flag = Path()
      ..moveTo(c.dx - 2, c.dy - 5)
      ..lineTo(c.dx + 5, c.dy - 2.5)
      ..lineTo(c.dx - 2, c.dy)
      ..close();
    canvas.drawPath(flag, Paint()..color = line);
  }

  void _dot(Canvas canvas, Offset c, {required bool live}) {
    if (live) {
      canvas.drawCircle(c, 16, Paint()..color = line.withValues(alpha: 0.22));
    }
    canvas.drawCircle(c, 8, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5.5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.route.length != route.length ||
      old.current != current ||
      old.dark != dark ||
      old.line != line;
}
