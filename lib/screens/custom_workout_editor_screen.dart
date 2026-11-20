import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/custom_workout.dart';
import '../models/exercise.dart';
import '../services/custom_workout_store.dart';
import '../widgets/exercise/exercise_thumbnail.dart';
import 'checkout_screen.dart' show GlassPanel;
import 'exercise_detail_screen.dart';
import 'workout_session_screen.dart';

/// Build or edit a workout on one screen: name, exercises (search to add,
/// drag to reorder, remove), sets and reps or seconds, and a live summary.
/// Nothing is asked twice: Save keeps the workout, Save & start also begins it.
class CustomWorkoutEditorScreen extends StatefulWidget {
  const CustomWorkoutEditorScreen({super.key, this.existing, this.store});

  final CustomWorkout? existing;
  final CustomWorkoutStore? store;

  @override
  State<CustomWorkoutEditorScreen> createState() =>
      _CustomWorkoutEditorScreenState();
}

class _CustomWorkoutEditorScreenState extends State<CustomWorkoutEditorScreen> {
  late final CustomWorkoutStore _store = widget.store ?? CustomWorkoutStore();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? 'My workout',
  );
  late final List<CustomExercise> _exercises = [...?widget.existing?.exercises];
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    // Taken now, before any edit, so unsaved changes can be detected.
    _initialSnapshot = _snapshot();
  }

  bool _saving = false;
  bool _triedSave = false;

  String _snapshot() => CustomWorkout.encodeAll([
    CustomWorkout(
      id: 'x',
      name: _name.text.trim(),
      exercises: _exercises,
      createdAt: DateTime(2000),
      updatedAt: DateTime(2000),
    ),
  ]);

  bool get _dirty => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Give your workout a name.';
    if (n.length > CustomWorkout.maxNameLength) {
      return 'Keep the name under ${CustomWorkout.maxNameLength} characters.';
    }
    return null;
  }

  bool get _valid => _nameError == null && _exercises.isNotEmpty;

  Future<void> _addExercises() async {
    final picked = await showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ExercisePickerSheet(
        alreadyAdded: {for (final e in _exercises) e.exerciseId},
        room: CustomWorkout.maxExercises - _exercises.length,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      for (final e in picked) {
        _exercises.add(
          CustomExercise(
            exerciseId: e.id,
            name: e.name,
            muscleGroup: e.muscleGroup,
            durationSec: e.durationSeconds,
          ),
        );
      }
    });
  }

  void _update(int i, CustomExercise e) => setState(() => _exercises[i] = e);

  Future<CustomWorkout?> _save() async {
    setState(() => _triedSave = true);
    if (!_valid || _saving) return null;
    setState(() => _saving = true);
    try {
      final base = widget.existing ?? _store.blank(_name.text.trim());
      final saved = await _store.save(
        base.copyWith(name: _name.text.trim(), exercises: _exercises),
      );
      return saved;
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the workout. Your changes are still here.',
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveAndClose() async {
    final saved = await _save();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _saveAndStart() async {
    final saved = await _save();
    if (saved == null || !mounted) return;
    final nav = Navigator.of(context);
    nav.pop(saved);
    nav.push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          workoutName: saved.name,
          workoutId: 'custom_${saved.id}',
          initialExercises: saved.toSessionExercises(),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your changes to this workout have not been saved.',
        ),
        actions: [
          TextButton(
            key: const Key('keep_editing'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            key: const Key('discard_changes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final draft = CustomWorkout(
      id: 'draft',
      name: _name.text,
      exercises: _exercises,
      createdAt: DateTime(2000),
      updatedAt: DateTime(2000),
    );
    return PopScope(
      // Only a workout with unsaved changes asks before closing.
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appBackground,
          elevation: 0,
          title: Text(widget.existing == null ? 'New workout' : 'Edit workout'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  TextField(
                    key: const Key('workout_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: CustomWorkout.maxNameLength,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Workout name',
                      hintText: 'e.g. Push day',
                      counterText: '',
                      errorText: _triedSave ? _nameError : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EXERCISES',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                      if (_exercises.isNotEmpty)
                        TextButton.icon(
                          key: const Key('add_exercise'),
                          onPressed:
                              _exercises.length >= CustomWorkout.maxExercises
                              ? null
                              : _addExercises,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_exercises.isEmpty) _emptyState(context),
                  if (_exercises.isNotEmpty)
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorderItem: (oldIndex, newIndex) => setState(() {
                        final e = _exercises.removeAt(oldIndex);
                        _exercises.insert(newIndex, e);
                      }),
                      children: [
                        for (var i = 0; i < _exercises.length; i++)
                          _ExerciseCard(
                            key: ValueKey(
                              '${_exercises[i].exerciseId}_$i${_exercises.length}',
                            ),
                            index: i,
                            exercise: _exercises[i],
                            onChanged: (e) => _update(i, e),
                            onRemove: () =>
                                setState(() => _exercises.removeAt(i)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            _summaryBar(context, draft),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final error = _triedSave && _exercises.isEmpty;
    return GlassPanel(
      key: const Key('exercises_empty'),
      borderColor: error ? const Color(0xFFF87171) : null,
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 34,
            color: context.appPrimary,
          ),
          const SizedBox(height: 10),
          Text(
            error ? 'Add at least one exercise to save.' : 'No exercises yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search the exercise library and pick the movements you want.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('add_exercise_empty'),
            onPressed: _addExercises,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add exercises'),
            style: FilledButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(BuildContext context, CustomWorkout draft) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appOutlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _exercises.isEmpty
                ? 'Add exercises to see the summary'
                : '${_exercises.length} exercise${_exercises.length == 1 ? '' : 's'}'
                      ' · ${draft.totalSets} sets'
                      ' · about ${draft.estimatedMinutes} min (estimate)',
            key: const Key('workout_summary'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('save_workout'),
                  onPressed: _saving ? null : _saveAndClose,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: context.appPrimary,
                    side: BorderSide(color: context.appPrimary),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('save_and_start'),
                  onPressed: _saving ? null : _saveAndStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appPrimary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text(
                    'Save & start',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.index,
    required this.exercise,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final CustomExercise exercise;
  final ValueChanged<CustomExercise> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumbnail(
                  exerciseId: e.exerciseId,
                  exerciseName: e.name,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.appTextPrimary,
                        ),
                      ),
                      if (e.muscleGroup.isNotEmpty)
                        Text(
                          e.muscleGroup,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('remove_exercise_$index'),
                  tooltip: 'Remove exercise',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  color: context.appTextSecondary,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: 40,
                    height: 44,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      key: Key('drag_exercise_$index'),
                      color: context.appTextMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Stepper(
                  keyPrefix: 'sets_$index',
                  label: 'Sets',
                  value: e.sets,
                  min: 1,
                  max: CustomExercise.maxSets,
                  onChanged: (v) => onChanged(e.copyWith(sets: v)),
                ),
                if (e.isTimed)
                  _Stepper(
                    keyPrefix: 'secs_$index',
                    label: 'Seconds',
                    value: e.durationSec!,
                    min: 5,
                    max: CustomExercise.maxDurationSec,
                    step: 5,
                    onChanged: (v) => onChanged(e.copyWith(durationSec: v)),
                  )
                else
                  _Stepper(
                    keyPrefix: 'reps_$index',
                    label: 'Reps',
                    value: e.reps,
                    min: 1,
                    max: CustomExercise.maxReps,
                    onChanged: (v) => onChanged(e.copyWith(reps: v)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String keyPrefix;
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: Key('${keyPrefix}_minus'),
          tooltip: 'Fewer $label',
          onPressed: value > min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            key: Key('${keyPrefix}_value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: Key('${keyPrefix}_plus'),
          tooltip: 'More $label',
          onPressed: value < max ? () => onChanged(value + step) : null,
          icon: Icon(Icons.add_circle_rounded, color: context.appPrimary),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }
}

/// Search the exercise library and pick one or more exercises.
class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({
    super.key,
    required this.alreadyAdded,
    required this.room,
    this.exercises,
  });

  final Set<String> alreadyAdded;

  /// How many more exercises the workout can take.
  final int room;

  /// Overrides the built-in library (for tests).
  final List<Exercise>? exercises;

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  late final List<Exercise> _all =
      widget.exercises ?? Exercise.defaultRegistry();
  final _search = TextEditingController();
  String _muscle = 'All';
  final Map<String, Exercise> _picked = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _muscles {
    final set = {
      for (final e in _all)
        if (e.muscleGroup.isNotEmpty) e.muscleGroup,
    }.toList()..sort();
    return ['All', ...set];
  }

  List<Exercise> get _results {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final e in _all)
        if ((_muscle == 'All' || e.muscleGroup == _muscle) &&
            (q.isEmpty ||
                e.name.toLowerCase().contains(q) ||
                e.muscleGroup.toLowerCase().contains(q) ||
                e.equipment.toLowerCase().contains(q)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appOutlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('exercise_search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search exercises, muscles or equipment',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final m in _muscles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: Key('muscle_$m'),
                      label: Text(m),
                      selected: _muscle == m,
                      onSelected: (_) => setState(() => _muscle = m),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        key: const Key('exercise_no_results'),
                        'No exercises match. Try another word or muscle group.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.appTextSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) => _tile(context, results[i]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('picker_add'),
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, _picked.values.toList()),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 50),
                ),
                child: Text(
                  _picked.isEmpty
                      ? 'Select exercises to add'
                      : 'Add ${_picked.length} exercise${_picked.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Exercise e) {
    final added = widget.alreadyAdded.contains(e.id);
    final selected = _picked.containsKey(e.id);
    final full = !selected && _picked.length >= widget.room;
    return ListTile(
      key: Key('pick_${e.id}'),
      enabled: !added && !full,
      leading: ExerciseThumbnail(
        exerciseId: e.id,
        exerciseName: e.name,
        size: 46,
      ),
      title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        added
            ? 'Already in this workout'
            : [
                e.muscleGroup,
                e.equipment,
              ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('info_${e.id}'),
            tooltip: 'How to do ${e.name}',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseDetailScreen(
                  exercise: e,
                  enableWorkoutStart: false,
                ),
              ),
            ),
          ),
          Icon(
            added || selected
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: added || selected
                ? context.appPrimary
                : context.appTextSecondary,
          ),
        ],
      ),
      onTap: () => setState(() {
        if (selected) {
          _picked.remove(e.id);
        } else {
          _picked[e.id] = e;
        }
      }),
    );
  }
}
