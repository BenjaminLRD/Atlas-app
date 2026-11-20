// Renders the exercise thumbnails.
//
//   flutter test tool/exercise_thumbnails/render_test.dart --no-pub
//
// Writes one 360x360 PNG per exercise to build/thumbs_png/ (then run
// tool/exercise_thumbnails/compress.py to turn them into the shipped WebP
// files in assets/exercises/thumb_<id>.webp) and
// a contact sheet to build/thumbnail_sheet.png for looking over the whole set.
// Re-run it only when the illustrations change; the PNGs are committed assets,
// nothing is drawn at runtime.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:atlas/models/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'figure_painter.dart';
import 'thumbnail_poses.dart';

const double _px = 360;

Future<ui.Image> _render(ThumbSpec spec) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  FigurePainter(
    motion: spec.motion,
    pose: spec.pose,
    size: const Size(_px, _px),
    extraProps: spec.extra,
    behind: spec.behind,
    front: spec.front,
    floor: spec.floor,
    fitPoints: spec.fitPoints,
    towers: spec.towers,
  ).paint(canvas);
  return recorder.endRecording().toImage(_px.toInt(), _px.toInt());
}

Future<void> _writePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  testWidgets('render exercise thumbnails', (tester) async {
    await tester.runAsync(() async {
      final only = Platform.environment['THUMB_ONLY']
          ?.split(',')
          .where((s) => s.isNotEmpty)
          .toSet();
      final exercises = [
        for (final e in Exercise.defaultRegistry())
          if (only == null || only.contains(e.id)) e,
      ];
      final images = <String, ui.Image>{};
      for (final e in exercises) {
        final spec = thumbSpecFor(e.id);
        final image = await _render(spec);
        images[e.id] = image;
        if (only == null) {
          await _writePng(image, 'build/thumbs_png/thumb_${e.id}.png');
        }
      }

      // Contact sheet: 9 columns.
      final cols = only == null ? 9 : 4;
      final cell = only == null ? 200.0 : 420.0;
      const label = 18.0;
      final rows = (exercises.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, cols * cell, rows * (cell + label)),
        Paint()..color = const Color(0xFF000000),
      );
      for (var i = 0; i < exercises.length; i++) {
        final x = (i % cols) * cell, y = (i ~/ cols) * (cell + label);
        c.drawImageRect(
          images[exercises[i].id]!,
          const Rect.fromLTWH(0, 0, _px, _px),
          Rect.fromLTWH(x, y + label, cell, cell),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: exercises[i].id,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: cell);
        tp.paint(c, Offset(x + 3, y + 2));
      }
      final sheet = await rec.endRecording().toImage(
        (cols * cell).toInt(),
        (rows * (cell + label)).toInt(),
      );
      await _writePng(
        sheet,
        only == null ? 'build/thumbnail_sheet.png' : 'build/thumbnail_zoom.png',
      );
    });
  });
}
