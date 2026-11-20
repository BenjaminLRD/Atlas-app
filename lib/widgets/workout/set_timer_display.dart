import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/set_timer.dart';

/// Shows the running time of the set in progress, e.g. `00:32`.
///
/// It only reads [SetTimer.elapsed] a few times a second. The count itself
/// belongs to the timer, so rebuilding or recreating this widget never resets
/// or skews it.
class SetTimerDisplay extends StatefulWidget {
  final SetTimer timer;
  const SetTimerDisplay({super.key, required this.timer});

  @override
  State<SetTimerDisplay> createState() => _SetTimerDisplayState();
}

class _SetTimerDisplayState extends State<SetTimerDisplay> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          'SET TIME',
          style: AppTheme.labelCaps.copyWith(
            color: context.appTextSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          SetTimer.format(widget.timer.elapsed),
          key: const Key('set_timer_value'),
          style: AppTheme.headlineMd.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
