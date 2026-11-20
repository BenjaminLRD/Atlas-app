import 'dart:math' as math;

import '../../models/cardio_route.dart';
import '../cardio/cardio_tracker.dart';
import 'sample_world.dart';

/// Sample running and cycling activities for the built-in sample community.
///
/// Everything here is invented demonstration content, like the rest of
/// `SampleWorld`. The routes are generated loops around a made-up start point,
/// never a real GPS recording, and every post is flagged `sampleRoute` so the
/// UI labels it. The figures inside one activity agree with each other: the
/// distance is the length of the drawn route, the duration follows from the
/// speed, and the pace, speed and calories are derived from those.
class SampleCardio {
  const SampleCardio._();

  // A made-up point in the sample athletes' home town.
  static const double _lat0 = 23.7271;
  static const double _lng0 = 92.7176;

  /// A loop of exactly [km] kilometres, drawn as [points] positions.
  /// [seed] changes its shape; [openness] leaves a gap so the start and the
  /// finish are not the same spot.
  static List<RoutePoint> loop({
    required double km,
    required int seed,
    int points = 80,
    double openness = 0.06,
    double centreLatOffset = 0,
    double centreLngOffset = 0,
  }) {
    final rnd = math.Random(seed);
    final p1 = rnd.nextDouble() * 6.28;
    final p2 = rnd.nextDouble() * 6.28;
    final a2 = 0.16 + rnd.nextDouble() * 0.14;
    final a3 = 0.08 + rnd.nextDouble() * 0.1;
    final stretch = 0.7 + rnd.nextDouble() * 0.6;
    final turns = (1 - openness) * 2 * math.pi;

    List<(double, double)> unit() => [
      for (var i = 0; i < points; i++)
        () {
          final t = turns * i / (points - 1);
          final r = 1 + a2 * math.sin(2 * t + p1) + a3 * math.sin(3 * t + p2);
          return (r * math.cos(t) * stretch, r * math.sin(t));
        }(),
    ];

    final u = unit();
    var len = 0.0;
    for (var i = 1; i < u.length; i++) {
      len += math.sqrt(
        math.pow(u[i].$1 - u[i - 1].$1, 2) + math.pow(u[i].$2 - u[i - 1].$2, 2),
      );
    }
    final scaleM = (km * 1000) / len;
    final cosLat = math.cos(_lat0 * math.pi / 180);
    final lat = _lat0 + centreLatOffset;
    final lng = _lng0 + centreLngOffset;
    return [
      for (final p in u)
        RoutePoint(
          lat + (p.$2 * scaleM) / 111320,
          lng + (p.$1 * scaleM) / (111320 * cosLat),
        ),
    ];
  }

  static Map<String, dynamic> _meta({
    required CardioKind kind,
    required int seed,
    required double km,
    required double avgKmh,
    double? weightKg,
    double latOffset = 0,
    double lngOffset = 0,
  }) {
    final route = loop(
      km: km,
      seed: seed,
      centreLatOffset: latOffset,
      centreLngOffset: lngOffset,
    );
    // The distance is the real length of the drawn route, rounded.
    final distance = double.parse(
      (Geo.routeLengthM(route) / 1000).toStringAsFixed(2),
    );
    final seconds = (distance / avgKmh * 3600).round();
    final speed = distance / (seconds / 3600);
    final kcal = CardioTracker.estimateCalories(
      kind,
      weightKg,
      speed,
      Duration(seconds: seconds),
    );
    return {
      'activity': kind.key,
      'distanceKm': distance,
      'durationSeconds': seconds,
      'avgSpeedKmh': double.parse(speed.toStringAsFixed(2)),
      'avgPaceSecPerKm': (3600 / speed).round(),
      if (kcal != null) ...{
        'calories': kcal.round(),
        'caloriesEstimated': true,
      },
      'route': [
        for (final p in route)
          [
            double.parse(p.lat.toStringAsFixed(5)),
            double.parse(p.lng.toStringAsFixed(5)),
          ],
      ],
      'sampleRoute': true,
    };
  }

  static final List<SamplePost> posts = [
    SamplePost(
      'zothanpuii',
      21,
      'cardio',
      'Easy 5 before work',
      'Easy pace on purpose. Heart rate stayed low and I could talk the whole way, which is the point of the easy day.',
      5,
      meta: _meta(
        kind: CardioKind.running,
        seed: 11,
        km: 5.2,
        avgKmh: 9.4,
        weightKg: 58,
      ),
      likedBy: const ['maya', 'coach_zuala', 'jenny'],
      extraLikes: 14,
      saves: 2,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Good. Keep the easy days this easy and the hard days will be hard.',
          18,
        ),
        SampleComment('jenny', 'That pace would be a race for me.', 35),
      ],
    ),
    SamplePost(
      'zothanpuii',
      22,
      'cardio',
      'Tempo Thursday',
      'Three kilometres at tempo in the middle, warm up and cool down either side. The second tempo kilometre was the hardest.',
      52,
      meta: _meta(
        kind: CardioKind.running,
        seed: 23,
        km: 8.1,
        avgKmh: 11.2,
        weightKg: 58,
        latOffset: 0.004,
        lngOffset: -0.003,
      ),
      likedBy: const ['hminga', 'david'],
      extraLikes: 21,
      saves: 5,
      comments: const [
        SampleComment('hminga', 'Pace was steady all the way. Nice.', 40),
      ],
    ),
    SamplePost(
      'zothanpuii',
      23,
      'cardio',
      'Sunday long run',
      'Longest run of the block so far. Walked the last hill and I am fine with that. Fuel earlier next time.',
      118,
      meta: _meta(
        kind: CardioKind.running,
        seed: 37,
        km: 15.3,
        avgKmh: 9.9,
        weightKg: 58,
        latOffset: -0.006,
        lngOffset: 0.005,
      ),
      likedBy: const ['maya', 'alex', 'coach_zuala', 'marcus'],
      extraLikes: 33,
      saves: 9,
      comments: const [
        SampleComment(
          'alex',
          'Fifteen kilometres. I get tired driving that far.',
          25,
        ),
        SampleComment(
          'coach_zuala',
          'Eat something by kilometre 6 next time, not kilometre 11.',
          55,
        ),
      ],
    ),
    SamplePost(
      'liam',
      21,
      'cardio',
      'First ride back on the bike',
      'First proper ride since the knee. Kept it flat and gentle, no pain. That is the whole report.',
      9,
      meta: _meta(
        kind: CardioKind.cycling,
        seed: 41,
        km: 12.4,
        avgKmh: 17.5,
        weightKg: 72,
        latOffset: 0.003,
        lngOffset: 0.004,
      ),
      likedBy: const ['maya', 'coach_zuala', 'daniel'],
      extraLikes: 18,
      saves: 1,
      comments: const [
        SampleComment(
          'coach_zuala',
          'No pain is the report I wanted. Add ten minutes next week, not more.',
          30,
        ),
      ],
    ),
    SamplePost(
      'jenny',
      21,
      'cardio',
      'Saturday spin around the lake',
      'Took the long way round on the bike instead of the usual treadmill. Wind in my face for half of it, which I count as intervals.',
      27,
      meta: _meta(
        kind: CardioKind.cycling,
        seed: 53,
        km: 21.8,
        avgKmh: 21.6,
        weightKg: 64,
        latOffset: -0.003,
        lngOffset: -0.005,
      ),
      likedBy: const ['maya', 'sophia', 'alex'],
      extraLikes: 24,
      saves: 3,
      comments: const [
        SampleComment(
          'sophia',
          'Twenty-one kilometres?! Take me next time.',
          12,
        ),
        SampleComment('jenny', 'Come along. Slow group, I promise.', 20),
      ],
    ),
    SamplePost(
      'david',
      21,
      'cardio',
      'Run with the dog',
      'Neither of us was fast. Both of us were happy. Four kilometres is plenty after a leg day.',
      33,
      meta: _meta(
        kind: CardioKind.running,
        seed: 61,
        km: 4.3,
        avgKmh: 8.1,
        weightKg: 78,
        latOffset: 0.002,
        lngOffset: -0.002,
      ),
      likedBy: const ['alex', 'liam'],
      extraLikes: 9,
      saves: 0,
      comments: const [
        SampleComment('alex', 'The dog is the real athlete here.', 22),
      ],
    ),
    SamplePost(
      'hminga',
      21,
      'cardio',
      'Hill repeats before football',
      'Six hard hill efforts with a jog down between each. My legs left at repeat five and my lungs followed.',
      70,
      meta: _meta(
        kind: CardioKind.running,
        seed: 71,
        km: 6.0,
        avgKmh: 10.1,
        weightKg: 74,
        latOffset: 0.005,
        lngOffset: 0.002,
      ),
      likedBy: const ['zothanpuii', 'coach_zuala', 'marcus'],
      extraLikes: 16,
      saves: 4,
      comments: const [
        SampleComment(
          'coach_zuala',
          'Repeat five is where the work counts. Same plan next week, add one.',
          44,
        ),
      ],
    ),
    SamplePost(
      'daniel',
      21,
      'cardio',
      'Evening spin, nothing fancy',
      'Thirty-odd minutes on the bike after dinner to loosen the hips. No plan, no targets, just pedalling.',
      98,
      meta: _meta(
        kind: CardioKind.cycling,
        seed: 83,
        km: 11.2,
        avgKmh: 19.0,
        latOffset: -0.002,
        lngOffset: 0.006,
      ),
      likedBy: const ['maya', 'sophia'],
      extraLikes: 7,
      saves: 1,
      comments: const [
        SampleComment('maya', 'The loosen-the-hips ride is underrated.', 31),
      ],
    ),
    SamplePost(
      'marcus',
      21,
      'cardio',
      'Park loop, three laps',
      'Three laps of the park path between muscle-up sets. A cardio day that does not feel like one.',
      140,
      meta: _meta(
        kind: CardioKind.running,
        seed: 97,
        km: 3.6,
        avgKmh: 9.0,
        weightKg: 70,
        latOffset: 0.001,
        lngOffset: 0.001,
      ),
      likedBy: const ['jenny', 'alex'],
      extraLikes: 11,
      saves: 2,
      comments: const [
        SampleComment(
          'jenny',
          'Cardio that does not feel like cardio, yes.',
          26,
        ),
      ],
    ),
  ];
}
