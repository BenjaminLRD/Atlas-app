import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/exercise/muscle_map.dart';
import 'muscle_body_painter.dart';

/// The body figure with the muscles a workout or an exercise works, a legend,
/// and the names of the muscle groups.
///
/// A Front / Back switch appears only when both sides show a highlighted
/// muscle; with a single side there is nothing to switch.
class MuscleMapCard extends StatefulWidget {
  final MuscleActivation activation;
  final String title;
  final String? subtitle;

  /// Extra widgets under the labels (for example a button).
  final Widget? footer;

  const MuscleMapCard({
    super.key,
    required this.activation,
    this.title = 'MUSCLES TARGETED',
    this.subtitle,
    this.footer,
  });

  @override
  State<MuscleMapCard> createState() => _MuscleMapCardState();
}

class _MuscleMapCardState extends State<MuscleMapCard> {
  MuscleView? _chosen;

  /// The side being shown: the user's choice while it still shows something,
  /// otherwise the best default for the current muscles.
  MuscleView get _view {
    final a = widget.activation;
    final chosen = _chosen;
    if (chosen != null && a.availableViews.contains(chosen)) return chosen;
    return a.defaultView;
  }

  @override
  void didUpdateWidget(MuscleMapCard old) {
    super.didUpdateWidget(old);
    if (old.activation.primary != widget.activation.primary ||
        old.activation.secondary != widget.activation.secondary) {
      // A different exercise: start from its own best side again.
      _chosen = null;
    }
  }

  static String _names(Set<MuscleRegion> regions) {
    final sorted = regions.toList()..sort((a, b) => a.index - b.index);
    return sorted.map((r) => r.label).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activation;
    final view = _view;
    final label = StringBuffer('Muscle map, ${view.name} view. ');
    if (a.primary.isNotEmpty) {
      label.write('Primary: ${_names(a.primary)}. ');
    }
    if (a.secondary.isNotEmpty) {
      label.write('Secondary: ${_names(a.secondary)}.');
    }

    return Container(
      key: const Key('muscle_map_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.accessibility_new_rounded,
                size: 18,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTheme.labelCaps.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              if (a.hasBothViews)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _viewSwitch(context, view),
                  ),
                ),
            ],
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            ),
          ],
          const SizedBox(height: 12),
          if (!a.isComplete)
            _incomplete(context)
          else
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 300;
                final figureHeight = (c.maxWidth * 0.85).clamp(240.0, 330.0);
                final figure = Semantics(
                  label: label.toString(),
                  image: true,
                  child: ExcludeSemantics(
                    child: Container(
                      key: const Key('muscle_body'),
                      height: figureHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MuscleBodyColors.panelTop,
                            MuscleBodyColors.panelBottom,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: MuscleBodyPainter(activation: a, view: view),
                        ),
                      ),
                    ),
                  ),
                );
                final labels = _labels(context, a);
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: SizedBox(width: 170, child: figure)),
                      const SizedBox(height: 12),
                      labels,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: figure),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: labels),
                  ],
                );
              },
            ),
          if (widget.footer != null) ...[
            const SizedBox(height: 12),
            widget.footer!,
          ],
        ],
      ),
    );
  }

  Widget _viewSwitch(BuildContext context, MuscleView view) {
    Widget chip(MuscleView v, String text) {
      final selected = v == view;
      return Semantics(
        button: true,
        selected: selected,
        label: '$text view',
        child: GestureDetector(
          key: Key('muscle_view_${v.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _chosen = v),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryContainer.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(
                color: selected
                    ? AppColors.primaryContainer
                    : context.appOutlineVariant,
              ),
            ),
            child: Text(
              text,
              style: AppTheme.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primaryContainer
                    : context.appTextSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(MuscleView.front, 'Front'),
        const SizedBox(width: 6),
        chip(MuscleView.back, 'Back'),
      ],
    );
  }

  Widget _incomplete(BuildContext context) {
    return Container(
      key: const Key('muscle_map_incomplete'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Text(
        'No muscle map for this yet. The exercise does not list the muscles '
        'it works, and Atlas does not guess.',
        style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
      ),
    );
  }

  Widget _labels(BuildContext context, MuscleActivation a) {
    Widget legendRow(Color color, String text, {bool outline = false}) => Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outline ? color.withValues(alpha: 0.42) : color,
            borderRadius: BorderRadius.circular(3),
            border: outline ? Border.all(color: color, width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: AppTheme.bodySm.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
        ),
      ],
    );

    Widget group(Key key, Widget legend, Set<MuscleRegion> regions) {
      final sorted = regions.toList()..sort((x, y) => x.index - y.index);
      return Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          legend,
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in sorted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    r.label,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.primary.isNotEmpty) ...[
          group(
            const Key('muscle_primary_group'),
            legendRow(MuscleBodyColors.emerald, 'Primary'),
            a.primary,
          ),
          const SizedBox(height: 12),
        ],
        if (a.secondary.isNotEmpty) ...[
          group(
            const Key('muscle_secondary_group'),
            legendRow(MuscleBodyColors.emerald, 'Secondary', outline: true),
            a.secondary,
          ),
          const SizedBox(height: 12),
        ],
        if (a.general)
          Text(
            key: const Key('muscle_general_note'),
            'Full-body work: the whole body is involved, so no single muscle '
            'is singled out.',
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
        if (a.unmapped.isNotEmpty)
          Text(
            key: const Key('muscle_unmapped_note'),
            'Not shown on the map: ${a.unmapped.join(', ')}.',
            style: AppTheme.bodySm.copyWith(
              fontSize: 11,
              color: context.appTextSecondary,
            ),
          ),
      ],
    );
  }
}

/// A bottom sheet with the muscle map of a whole workout, and a way to look at
/// one exercise of it instead.
class MuscleMapSheet extends StatefulWidget {
  final String workoutName;
  final List<Map<String, dynamic>> exercises;

  const MuscleMapSheet({
    super.key,
    required this.workoutName,
    required this.exercises,
  });

  static Future<void> show(
    BuildContext context, {
    required String workoutName,
    required List<Map<String, dynamic>> exercises,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          MuscleMapSheet(workoutName: workoutName, exercises: exercises),
    );
  }

  @override
  State<MuscleMapSheet> createState() => _MuscleMapSheetState();
}

class _MuscleMapSheetState extends State<MuscleMapSheet> {
  /// `null` is the whole workout; otherwise the index of one exercise.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final exercises = widget.exercises;
    final selected = _selected;
    final single = selected != null && selected < exercises.length;
    final activation = single
        ? MuscleMap.forPlanExercise(exercises[selected])
        : MuscleMap.forWorkout(exercises);
    final title = single
        ? (exercises[selected]['name']?.toString() ?? 'Exercise')
        : widget.workoutName;

    Widget chip(String text, bool on, VoidCallback tap, Key key) => ChoiceChip(
      key: key,
      label: Text(text),
      selected: on,
      onSelected: (_) => tap(),
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.25),
      labelStyle: AppTheme.bodySm.copyWith(
        fontWeight: FontWeight.w700,
        color: on ? AppColors.primaryContainer : context.appTextSecondary,
      ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appOutlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(
                    'Whole workout',
                    !single,
                    () => setState(() => _selected = null),
                    const Key('muscle_select_all'),
                  ),
                  for (var i = 0; i < exercises.length; i++) ...[
                    const SizedBox(width: 8),
                    chip(
                      exercises[i]['name']?.toString() ?? 'Exercise',
                      selected == i,
                      () => setState(() => _selected = i),
                      Key('muscle_select_$i'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            MuscleMapCard(
              title: single ? 'MUSCLES WORKED' : 'MUSCLES TARGETED',
              subtitle: title,
              activation: activation,
            ),
          ],
        ),
      ),
    );
  }
}
