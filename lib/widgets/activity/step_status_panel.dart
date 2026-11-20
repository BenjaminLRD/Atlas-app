import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/steps/step_counter_service.dart';
import '../../services/steps/step_models.dart';

String _thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : '$b';
}

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The words under the step count: where it comes from, or what is needed.
/// Pure so it can be tested without a widget.
class StepStatusText {
  /// One short line about the reading, or the problem when there is none.
  final String message;

  /// Label of the one action that can fix the problem (null when none).
  final String? actionLabel;

  /// True when the action asks for the permission, false when it opens the
  /// system settings.
  final bool actionRequestsPermission;

  const StepStatusText(
    this.message, {
    this.actionLabel,
    this.actionRequestsPermission = false,
  });

  /// A few words for a small card when there is no reading.
  static String shortHint(StepSensorStatus status, {bool supported = true}) {
    if (!supported) return 'Counts on phones';
    switch (status) {
      case StepSensorStatus.needsPermission:
        return 'Tap to allow step counting';
      case StepSensorStatus.permissionPermanentlyDenied:
        return 'Tap to open settings';
      case StepSensorStatus.unavailable:
        return 'No step sensor on this phone';
      case StepSensorStatus.waitingForFirstReading:
        return 'Waiting for first reading';
      case StepSensorStatus.active:
        return 'No steps counted yet';
      case StepSensorStatus.idle:
        return 'Starting step counter';
    }
  }

  static StepStatusText of(
    StepSensorStatus status,
    DayStepTotal today, {
    bool supported = true,
  }) {
    if (today.hasReading) {
      final phone = today.phoneSteps;
      final hc = today.healthConnectSteps;
      if (today.source == StepSource.healthConnect) {
        final other = phone == null
            ? ''
            : ' · Phone sensor ${_thousands(phone)}';
        final qualifier = today.sourcesDisagree ? ' (higher)' : '';
        return StepStatusText('From Health Connect$qualifier$other');
      }
      final since = today.phoneSince == null
          ? ''
          : ' · counting since ${_time(today.phoneSince!)}';
      final other = (hc != null && today.sourcesDisagree)
          ? ' · Health Connect ${_thousands(hc)}'
          : '';
      return StepStatusText('Phone step counter$since$other');
    }
    if (!supported) {
      return const StepStatusText('Step counting works on phones.');
    }
    switch (status) {
      case StepSensorStatus.needsPermission:
        return const StepStatusText(
          'Allow physical activity so Atlas can count your steps with your phone\'s sensor.',
          actionLabel: 'Allow step counting',
          actionRequestsPermission: true,
        );
      case StepSensorStatus.permissionPermanentlyDenied:
        return const StepStatusText(
          'Android won\'t ask again. Turn on Physical activity in Atlas\'s app settings.',
          actionLabel: 'Open app settings',
        );
      case StepSensorStatus.unavailable:
        return const StepStatusText(
          'This phone has no step counter. Health Connect steps appear here if you allow it.',
        );
      case StepSensorStatus.waitingForFirstReading:
        return const StepStatusText(
          'Waiting for the first reading from your phone. Take a few steps.',
        );
      case StepSensorStatus.active:
        return const StepStatusText('No steps counted yet today.');
      case StepSensorStatus.idle:
        return const StepStatusText('Step counting is starting.');
    }
  }
}

/// Shows [StepStatusText] and its action button, and rebuilds when the step
/// counter changes.
class StepStatusPanel extends StatelessWidget {
  final StepCounterService? service;

  const StepStatusPanel({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final s = service ?? StepCounterService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final text = StepStatusText.of(
          s.status,
          s.today,
          supported: StepCounterService.isSupportedPlatform || service != null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.message,
              key: const Key('step_status_message'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
            if (text.actionLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('step_status_action'),
                  onPressed: () => text.actionRequestsPermission
                      ? s.requestPermission()
                      : s.openSettings(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: context.appOutlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    text.actionLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
