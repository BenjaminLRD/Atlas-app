import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/custom_workout.dart';
import '../services/custom_workout_store.dart';
import 'checkout_screen.dart' show GlassPanel;
import 'custom_workout_editor_screen.dart';
import 'workout_session_screen.dart';

/// The athlete's own workouts: start one, build a new one, edit, duplicate or
/// delete (delete is immediate with an Undo, never a confirmation dialog).
class CustomWorkoutsScreen extends StatefulWidget {
  const CustomWorkoutsScreen({super.key, this.store});

  final CustomWorkoutStore? store;

  @override
  State<CustomWorkoutsScreen> createState() => _CustomWorkoutsScreenState();
}

class _CustomWorkoutsScreenState extends State<CustomWorkoutsScreen> {
  late final CustomWorkoutStore _store = widget.store ?? CustomWorkoutStore();
  late List<CustomWorkout> _workouts = _store.all();

  void _reload() => setState(() => _workouts = _store.all());

  Future<void> _openEditor([CustomWorkout? existing]) async {
    await Navigator.of(context).push<CustomWorkout>(
      MaterialPageRoute(
        builder: (_) =>
            CustomWorkoutEditorScreen(existing: existing, store: _store),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _start(CustomWorkout w) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          workoutName: w.name,
          workoutId: 'custom_${w.id}',
          initialExercises: w.toSessionExercises(),
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _duplicate(CustomWorkout w) async {
    await _store.duplicate(w.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied "${w.name}".')));
  }

  Future<void> _delete(CustomWorkout w) async {
    await _store.delete(w.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${w.name}".'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _store.save(w);
              if (mounted) _reload();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: const Text('My workouts'),
      ),
      floatingActionButton: _workouts.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('new_workout'),
              onPressed: () => _openEditor(),
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New workout',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: _workouts.isEmpty
          ? _empty(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: _workouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _card(context, _workouts[i]),
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 48,
              color: context.appPrimary,
            ),
            const SizedBox(height: 14),
            Text(
              'Build your own workout',
              key: const Key('workouts_empty'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick exercises, set sets and reps, and start it any time. '
              'It takes about a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary, height: 1.35),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('new_workout_empty'),
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a workout'),
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, CustomWorkout w) {
    final names = w.exercises.map((e) => e.name).toList();
    final shown = names.take(3).join(', ');
    final more = names.length > 3 ? ' +${names.length - 3} more' : '';
    return GlassPanel(
      key: Key('workout_${w.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  w.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                key: Key('menu_${w.id}'),
                tooltip: 'More',
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _openEditor(w);
                    case 'duplicate':
                      _duplicate(w);
                    case 'delete':
                      _delete(w);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Text(
            '${w.exercises.length} exercise${w.exercises.length == 1 ? '' : 's'}'
            ' · ${w.totalSets} sets · about ${w.estimatedMinutes} min (estimate)',
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '$shown$more',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.appTextMuted),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: Key('start_${w.id}'),
              onPressed: w.exercises.isEmpty ? null : () => _start(w),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
