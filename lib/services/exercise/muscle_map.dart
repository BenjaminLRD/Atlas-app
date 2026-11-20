import '../../models/exercise.dart';

/// Which side of the body a muscle can be seen from.
enum MuscleView { front, back }

/// The muscle regions the body figure can highlight. Each one is a region that
/// really exists on the drawn figure, so a highlighted muscle always points at
/// a recognisable part of the body.
enum MuscleRegion {
  chest('Chest', {MuscleView.front}),
  frontDelts('Front delts', {MuscleView.front}),
  sideDelts('Side delts', {MuscleView.front, MuscleView.back}),
  rearDelts('Rear delts', {MuscleView.back}),
  traps('Traps', {MuscleView.front, MuscleView.back}),
  upperBack('Upper back', {MuscleView.back}),
  lats('Lats', {MuscleView.back}),
  lowerBack('Lower back', {MuscleView.back}),
  biceps('Biceps', {MuscleView.front}),
  triceps('Triceps', {MuscleView.back}),
  forearms('Forearms', {MuscleView.front, MuscleView.back}),
  abs('Abs', {MuscleView.front}),
  obliques('Obliques', {MuscleView.front}),
  hipFlexors('Hip flexors', {MuscleView.front}),
  glutes('Glutes', {MuscleView.back}),
  quads('Quads', {MuscleView.front}),
  adductors('Adductors', {MuscleView.front}),
  hamstrings('Hamstrings', {MuscleView.back}),
  calves('Calves', {MuscleView.front, MuscleView.back});

  final String label;
  final Set<MuscleView> views;
  const MuscleRegion(this.label, this.views);
}

/// How strongly a region is involved.
enum MuscleRole { none, secondary, primary }

/// The muscles an exercise (or a whole workout) works.
class MuscleActivation {
  final Set<MuscleRegion> primary;

  /// Regions that assist. Never contains a region that is also primary.
  final Set<MuscleRegion> secondary;

  /// True for full-body work (HIIT circuits, rowing intervals) where the
  /// exercise definition names no individual muscle. The whole body is shown
  /// as generally involved instead of guessing which parts.
  final bool general;

  /// Entries of the exercise definition that are not a displayable muscle,
  /// for example "Cardiovascular". They are kept so nothing disappears
  /// silently.
  final List<String> ignored;

  /// Entries nothing in the table could place. A non-empty list means the
  /// map may be missing something: it is flagged, never guessed.
  final List<String> unmapped;

  const MuscleActivation({
    this.primary = const {},
    this.secondary = const {},
    this.general = false,
    this.ignored = const [],
    this.unmapped = const [],
  });

  static const MuscleActivation empty = MuscleActivation();

  bool get hasAnyMuscle => primary.isNotEmpty || secondary.isNotEmpty;

  /// True when the map says something about the body.
  bool get isComplete => hasAnyMuscle || general;

  MuscleRole roleOf(MuscleRegion region) {
    if (primary.contains(region)) return MuscleRole.primary;
    if (secondary.contains(region)) return MuscleRole.secondary;
    return MuscleRole.none;
  }

  /// The views in which something is highlighted. A general (full-body)
  /// activation can be seen from both sides.
  Set<MuscleView> get availableViews {
    if (general) return {MuscleView.front, MuscleView.back};
    final views = <MuscleView>{};
    for (final r in [...primary, ...secondary]) {
      views.addAll(r.views);
    }
    return views;
  }

  /// Whether a front/back switch makes sense: both sides show something.
  bool get hasBothViews => availableViews.length > 1;

  /// The side to open on: the one showing more primary muscles (front on a
  /// tie), or the only one available.
  MuscleView get defaultView {
    final views = availableViews;
    if (views.length == 1) return views.first;
    int count(MuscleView v) => primary.where((r) => r.views.contains(v)).length;
    return count(MuscleView.back) > count(MuscleView.front)
        ? MuscleView.back
        : MuscleView.front;
  }

  /// Several activations as one: a region is primary if any exercise trains it
  /// as a primary muscle, otherwise secondary if any exercise assists with it.
  static MuscleActivation combine(Iterable<MuscleActivation> all) {
    final primary = <MuscleRegion>{};
    final secondary = <MuscleRegion>{};
    var general = false;
    final ignored = <String>[];
    final unmapped = <String>[];
    for (final a in all) {
      primary.addAll(a.primary);
      secondary.addAll(a.secondary);
      general = general || a.general;
      ignored.addAll(a.ignored);
      unmapped.addAll(a.unmapped);
    }
    secondary.removeAll(primary);
    return MuscleActivation(
      primary: primary,
      secondary: secondary,
      general: general,
      ignored: ignored,
      unmapped: unmapped,
    );
  }
}

/// Turns the muscle names already stored on each exercise into body regions.
///
/// The exercise definition stays the single source of truth: this file only
/// interprets its text. Names that are not a muscle (cardio, myofascial tissue)
/// are listed in [ignoredNames]; anything else the table cannot place is
/// reported in [MuscleActivation.unmapped] and fails the catalogue test.
class MuscleMap {
  const MuscleMap._();

  /// Names in exercise definitions that are deliberately not drawn.
  static const List<String> ignoredNames = [
    'cardiovascular',
    'cardio',
    'myofascial',
    'agility',
    'neck',
  ];

  static const Map<String, List<MuscleRegion>> _generic = {
    'legs': [
      MuscleRegion.quads,
      MuscleRegion.hamstrings,
      MuscleRegion.glutes,
      MuscleRegion.calves,
    ],
    'arms': [MuscleRegion.biceps, MuscleRegion.triceps, MuscleRegion.forearms],
  };

  /// Regions for one name from an exercise definition. `null` means the name
  /// is unknown; an empty list means it is known but not a drawn muscle.
  static List<MuscleRegion>? regionsForName(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return const [];
    bool has(String t) => s.contains(t);
    final latPattern = RegExp(r'(^|[^a-z])(lats?|latissimus)([^a-z]|$)');

    for (final ignored in ignoredNames) {
      if (s == ignored || s.startsWith('$ignored ')) return const [];
    }
    if (has('myofascial')) return const [];

    if (has('rear delt') || has('posterior delt') || has('rotator cuff')) {
      return const [MuscleRegion.rearDelts];
    }
    if (has('front delt') || has('anterior delt')) {
      return const [MuscleRegion.frontDelts];
    }
    if (has('side delt') || has('lateral delt') || has('medial delt')) {
      return const [MuscleRegion.sideDelts];
    }
    if (has('all 3 heads')) {
      return const [
        MuscleRegion.frontDelts,
        MuscleRegion.sideDelts,
        MuscleRegion.rearDelts,
      ];
    }
    if (has('shoulder') || has('delt')) {
      // Plain "shoulders" in a press: the front and side of the shoulder.
      return const [MuscleRegion.frontDelts, MuscleRegion.sideDelts];
    }
    if (has('chest') || has('pector')) return const [MuscleRegion.chest];
    if (has('trap')) return const [MuscleRegion.traps];
    if (has('rhomboid') ||
        has('upper back') ||
        has('middle back') ||
        has('mid back') ||
        has('thoracic')) {
      return const [MuscleRegion.upperBack];
    }
    if (latPattern.hasMatch(s)) return const [MuscleRegion.lats];
    if (has('lower back') || has('erector')) {
      return const [MuscleRegion.lowerBack];
    }
    if (has('spine') || has('spinal')) {
      return const [MuscleRegion.upperBack, MuscleRegion.lowerBack];
    }
    if (s == 'back') {
      return const [MuscleRegion.upperBack, MuscleRegion.lowerBack];
    }
    if (has('bicep') || has('brachialis')) return const [MuscleRegion.biceps];
    if (has('tricep')) return const [MuscleRegion.triceps];
    if (has('forearm') || has('grip')) return const [MuscleRegion.forearms];
    if (has('oblique')) return const [MuscleRegion.obliques];
    if (has('rectus abdominis') || has('abs')) return const [MuscleRegion.abs];
    if (has('core') || has('transverse')) {
      return const [MuscleRegion.abs, MuscleRegion.obliques];
    }
    if (has('hip flexor') || has('iliopsoas') || has('psoas')) {
      return const [MuscleRegion.hipFlexors];
    }
    if (has('quad') || has('rectus femoris')) return const [MuscleRegion.quads];
    if (has('hamstring')) return const [MuscleRegion.hamstrings];
    if (has('glute')) return const [MuscleRegion.glutes];
    if (has('adductor')) return const [MuscleRegion.adductors];
    if (has('calf') || has('calves') || has('gastrocnemius') || has('soleus')) {
      return const [MuscleRegion.calves];
    }
    final generic = _generic[s];
    if (generic != null) return generic;
    return null;
  }

  static bool _isFullBody(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return s == 'fullbody' || s == 'wholebody' || s == 'totalbody';
  }

  /// The muscles named by two lists of definition names.
  static MuscleActivation fromNames(
    Iterable<String> primaryNames,
    Iterable<String> secondaryNames,
  ) {
    final primary = <MuscleRegion>{};
    final secondary = <MuscleRegion>{};
    final ignored = <String>[];
    final unmapped = <String>[];
    var general = false;

    void read(Iterable<String> names, Set<MuscleRegion> into) {
      for (final name in names) {
        if (_isFullBody(name)) {
          general = true;
          continue;
        }
        final regions = regionsForName(name);
        if (regions == null) {
          unmapped.add(name);
        } else if (regions.isEmpty) {
          ignored.add(name);
        } else {
          into.addAll(regions);
        }
      }
    }

    read(primaryNames, primary);
    read(secondaryNames, secondary);
    secondary.removeAll(primary);
    return MuscleActivation(
      primary: primary,
      secondary: secondary,
      general: general,
      ignored: ignored,
      unmapped: unmapped,
    );
  }

  /// The muscles one catalogue exercise works.
  static MuscleActivation forExercise(Exercise exercise) =>
      fromNames(exercise.primaryMuscles, exercise.secondaryMuscles);

  static Map<String, Exercise>? _registry;

  static Exercise? _lookup(String? id) {
    if (id == null || id.isEmpty) return null;
    _registry ??= {for (final e in Exercise.defaultRegistry()) e.id: e};
    return _registry![id];
  }

  /// One exercise of a workout plan (the map form used by the workout
  /// screens). A catalogue exercise uses its definition; anything else falls
  /// back to the muscle text carried on the plan entry.
  static MuscleActivation forPlanExercise(Map<String, dynamic> ex) {
    final known = _lookup(ex['id']?.toString());
    if (known != null) return forExercise(known);
    final names = <String>[
      for (final key in const ['primaryTarget', 'muscleGroup'])
        if (ex[key] is String && (ex[key] as String).trim().isNotEmpty)
          ...(ex[key] as String).split(','),
    ];
    return fromNames(names.map((n) => n.trim()), const []);
  }

  /// The combined muscles of a whole workout.
  static MuscleActivation forWorkout(List<Map<String, dynamic>> exercises) =>
      MuscleActivation.combine(exercises.map(forPlanExercise));
}
