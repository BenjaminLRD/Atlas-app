import 'dart:io';
import 'dart:typed_data';

import 'package:atlas/app_theme.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise/exercise_thumbnails.dart';
import 'package:atlas/widgets/exercise/exercise_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Width and height of a lossy WebP, read from its VP8 header.
({int w, int h})? _webpSize(Uint8List b) {
  if (b.length < 30) return null;
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WEBP' || tag(12) != 'VP8 ') return null;
  final w = (b[26] | (b[27] << 8)) & 0x3fff;
  final h = (b[28] | (b[29] << 8)) & 0x3fff;
  return (w: w, h: h);
}

void main() {
  final exercises = Exercise.defaultRegistry();
  final ids = exercises.map((e) => e.id).toList();

  group('Exercise thumbnail mapping', () {
    test('every catalogue exercise has exactly one thumbnail', () {
      expect(exercises.length, 72);
      for (final id in ids) {
        expect(
          ExerciseThumbnails.assetFor(id),
          isNotNull,
          reason: '$id has no thumbnail',
        );
      }
      expect(ExerciseThumbnails.assets.length, ids.length);
    });

    test('there are no thumbnails for exercises that do not exist', () {
      for (final id in ExerciseThumbnails.assets.keys) {
        expect(ids, contains(id), reason: 'thumbnail for unknown id $id');
      }
      expect(ExerciseThumbnails.assetFor('not_an_exercise'), isNull);
    });

    test(
      'each exercise points at its own file, unless sharing is declared',
      () {
        final seen = <String, String>{};
        ExerciseThumbnails.assets.forEach((id, path) {
          expect(path, 'assets/exercises/thumb_$id.webp', reason: id);
          final other = seen[path];
          if (other != null) {
            expect(
              ExerciseThumbnails.intentionallyShared,
              allOf(contains(id), contains(other)),
              reason: '$id and $other share $path without saying so',
            );
          }
          seen[path] = id;
        });
      },
    );

    test('every mapped file exists, is a valid 360x360 WebP, and is small', () {
      for (final entry in ExerciseThumbnails.assets.entries) {
        final file = File(entry.value);
        expect(file.existsSync(), isTrue, reason: 'missing ${entry.value}');
        final bytes = file.readAsBytesSync();
        final size = _webpSize(bytes);
        expect(size, isNotNull, reason: '${entry.value} is not a lossy WebP');
        expect(size!.w, 360, reason: entry.value);
        expect(size.h, 360, reason: entry.value);
        expect(bytes.length, lessThan(40 * 1024), reason: entry.value);
        expect(bytes.length, greaterThan(2 * 1024), reason: entry.value);
      }
    });

    test('no two exercises show the same picture', () {
      final byContent = <String, String>{};
      ExerciseThumbnails.assets.forEach((id, path) {
        final key = File(path).readAsBytesSync().join(',');
        final other = byContent[key];
        expect(other, isNull, reason: '$id is identical to $other');
        byContent[key] = id;
      });
    });

    test('no stray thumbnail files lie around unmapped', () {
      final onDisk = Directory('assets/exercises')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => !n.startsWith('.'))
          .toSet();
      final mapped = ExerciseThumbnails.assets.values
          .map((p) => p.split('/').last)
          .toSet();
      expect(onDisk, mapped);
    });

    test('thumbnails are bundled with the app', () async {
      // Loading through the asset bundle proves pubspec declares them.
      for (final id in ['dumbbell_bench_press', 'lat_pulldown', 'plank']) {
        final data = await rootBundle.load(ExerciseThumbnails.assetFor(id)!);
        expect(data.lengthInBytes, greaterThan(2000), reason: id);
      }
    });

    test('none of the shown pictures is a photo or a borrowed video frame', () {
      // The old thumbnails came from remote photos and video frames. Every
      // catalogue thumbnail is now a bundled asset, never a URL.
      for (final path in ExerciseThumbnails.assets.values) {
        expect(path.startsWith('assets/exercises/'), isTrue);
        expect(path.contains('http'), isFalse);
      }
    });
  });

  group('ExerciseThumbnail widget', () {
    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('shows the exercise\'s own bundled illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ExerciseThumbnail(
            exerciseId: 'dumbbell_bench_press',
            exerciseName: 'Dumbbell Bench Press',
            size: 76,
          ),
        ),
      );
      final image = tester.widget<Image>(
        find.byKey(const Key('exercise_thumb_dumbbell_bench_press')),
      );
      final provider = image.image;
      expect(
        provider is ResizeImage
            ? (provider.imageProvider as AssetImage).assetName
            : (provider as AssetImage).assetName,
        'assets/exercises/thumb_dumbbell_bench_press.webp',
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('an exercise with no illustration gets a plain icon tile', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ExerciseThumbnail(
            exerciseId: 'my_custom_exercise',
            exerciseName: 'My custom exercise',
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    });
  });
}
