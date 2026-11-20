import 'package:atlas/app_theme.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/services/exercise/exercise_videos.dart';
import 'package:atlas/widgets/exercise/exercise_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exercises = Exercise.defaultRegistry();
  final ids = exercises.map((e) => e.id).toSet();

  group('Verified YouTube mapping', () {
    test('every exercise is either mapped to a video or says why not', () {
      for (final id in ids) {
        final has = ExerciseVideos.byExerciseId.containsKey(id);
        final lacks = ExerciseVideos.unavailable.containsKey(id);
        expect(has != lacks, isTrue, reason: '$id must be in exactly one');
      }
      expect(ExerciseVideos.byExerciseId.length, 69);
      expect(ExerciseVideos.unavailable.keys.toSet(), {
        'hiit_circuit',
        'football',
        'basketball',
      });
      for (final reason in ExerciseVideos.unavailable.values) {
        expect(reason.trim(), isNotEmpty);
      }
    });

    test('nothing is mapped for an exercise that does not exist', () {
      for (final id in [
        ...ExerciseVideos.byExerciseId.keys,
        ...ExerciseVideos.unavailable.keys,
      ]) {
        expect(ids, contains(id));
      }
    });

    test('every video id has the YouTube format and a real watch link', () {
      for (final e in ExerciseVideos.byExerciseId.entries) {
        final v = e.value;
        expect(
          ExerciseVideo.idPattern.hasMatch(v.videoId),
          isTrue,
          reason: '${e.key}: "${v.videoId}" is not an 11-character id',
        );
        final uri = v.watchUri;
        expect(uri.scheme, 'https');
        expect(uri.host, 'www.youtube.com');
        expect(uri.path, '/watch');
        expect(uri.queryParameters['v'], v.videoId);
      }
    });

    test('no video is used for two different exercises', () {
      final seen = <String, String>{};
      ExerciseVideos.byExerciseId.forEach((id, v) {
        final other = seen[v.videoId];
        expect(other, isNull, reason: '$id reuses the video of $other');
        seen[v.videoId] = id;
      });
    });

    test('each video\'s real title names the exercise it is linked to', () {
      for (final e in ExerciseVideos.byExerciseId.entries) {
        final v = e.value;
        expect(v.title.trim(), isNotEmpty, reason: e.key);
        expect(v.channel.trim(), isNotEmpty, reason: e.key);
        expect(v.matchTerms, isNotEmpty, reason: e.key);
        final title = v.title.toLowerCase();
        for (final term in v.matchTerms) {
          expect(
            title,
            contains(term.toLowerCase()),
            reason: '${e.key}: title "${v.title}" does not mention "$term"',
          );
        }
      }
    });

    test('equipment-specific exercises do not link the wrong equipment', () {
      String title(String id) =>
          ExerciseVideos.byExerciseId[id]!.title.toLowerCase();
      expect(title('dumbbell_bench_press'), contains('dumbbell'));
      expect(title('incline_bench_press'), isNot(contains('dumbbell')));
      expect(title('cable_lateral_raise'), contains('cable'));
      expect(title('romanian_deadlift'), isNot(contains('dumbbell')));
      expect(title('dumbbell_rdl'), contains('dumbbell'));
      expect(title('seated_calf_raise'), contains('seated'));
      expect(title('standing_calf_raise'), isNot(contains('seated')));
      expect(title('hammer_curl'), contains('hammer'));
      expect(title('bicep_curl'), isNot(contains('hammer')));
    });

    test('the verification date is recorded', () {
      expect(
        ExerciseVideos.verifiedOn,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });
  });

  group('Video option in the player', () {
    late List<Uri> opened;
    late List<String> copied;
    late bool launchResult;
    late bool launchThrows;

    setUp(() {
      opened = [];
      copied = [];
      launchResult = true;
      launchThrows = false;
      ExerciseVideoPlayer.launcher = (uri) async {
        opened.add(uri);
        if (launchThrows) throw Exception('no handler');
        return launchResult;
      };
      ExerciseVideoPlayer.copier = (text) async => copied.add(text);
    });

    tearDown(() {
      ExerciseVideoPlayer.launcher = ExerciseVideoPlayer.launcher;
    });

    Widget host(Exercise e) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(child: ExerciseVideoPlayer(exercise: e)),
      ),
    );

    Future<void> openVideoMode(WidgetTester tester, String id) async {
      await tester.pumpWidget(host(Exercise.getById(id)!));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('form_mode_video')));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Video shows the verified video and never the old error', (
      tester,
    ) async {
      await openVideoMode(tester, 'barbell_back_squat');
      final v = ExerciseVideos.forExercise('barbell_back_squat')!;
      expect(find.text(v.title), findsOneWidget);
      expect(find.textContaining(v.channel), findsOneWidget);
      expect(find.text('Watch on YouTube'), findsOneWidget);
      expect(find.textContaining('could not be played'), findsNothing);
      expect(find.textContaining('Check your connection'), findsNothing);
      expect(opened, isEmpty, reason: 'nothing opens until the user asks');
    });

    testWidgets('Watch on YouTube opens exactly the mapped video', (
      tester,
    ) async {
      await openVideoMode(tester, 'lat_pulldown');
      await tester.tap(find.byKey(const Key('exercise_video_play')));
      await tester.pump(const Duration(milliseconds: 50));
      final v = ExerciseVideos.forExercise('lat_pulldown')!;
      expect(opened, [v.watchUri]);
      expect(find.byKey(const Key('video_open_failed')), findsNothing);
    });

    testWidgets('when nothing can open the link, it says so and offers '
        'the link instead of a broken player', (tester) async {
      launchResult = false;
      await openVideoMode(tester, 'plank');
      await tester.tap(find.byKey(const Key('exercise_video_play')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('video_open_failed')), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exercise_video_copy')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(copied, [
        ExerciseVideos.forExercise('plank')!.watchUri.toString(),
      ]);

      // Trying again opens it once the connection is back.
      launchResult = true;
      await tester.tap(find.byKey(const Key('exercise_video_play')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(opened.length, 2);
      expect(find.byKey(const Key('video_open_failed')), findsNothing);
    });

    testWidgets('a launcher that throws is handled the same way', (
      tester,
    ) async {
      launchThrows = true;
      await openVideoMode(tester, 'push_ups');
      await tester.tap(find.byKey(const Key('exercise_video_play')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('video_open_failed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('exercises without an animation go straight to their video', (
      tester,
    ) async {
      await tester.pumpWidget(host(Exercise.getById('swimming')!));
      await tester.pump(const Duration(milliseconds: 100));
      final v = ExerciseVideos.forExercise('swimming')!;
      expect(find.text(v.title), findsOneWidget);
      expect(find.text('YOUTUBE DEMO'), findsOneWidget);
      expect(find.byKey(const Key('form_mode_video')), findsNothing);
    });

    testWidgets('an exercise with neither animation nor video says so', (
      tester,
    ) async {
      await tester.pumpWidget(host(Exercise.getById('football')!));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('no_demonstration')), findsOneWidget);
      expect(find.byKey(const Key('no_video_note')), findsOneWidget);
      expect(find.byKey(const Key('exercise_video_play')), findsNothing);
    });

    testWidgets('an unknown exercise never gets somebody else\'s video', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Exercise(id: 'my_custom_move', name: 'My custom move')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('exercise_video_play')), findsNothing);
      expect(find.byKey(const Key('no_video_note')), findsOneWidget);
    });
  });
}
