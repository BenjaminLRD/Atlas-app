import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_theme.dart';
import '../../services/health/platform_health_reader.dart';
import '../../services/steps/step_counter_service.dart';
import '../../services/steps/step_models.dart';
import '../../services/steps/step_permission.dart';
import '../../widgets/onboarding/onboarding_kit.dart';

/// The permissions Atlas can use today. Each one is optional.
enum OnboardingPermission { activity, location, health }

enum PermState { notAsked, granted, denied, permanentlyDenied, unavailable }

/// Asks the real platform APIs. A fake replaces it in tests. Nothing here is
/// called until the athlete taps a button: the step never asks by itself.
abstract class OnboardingPermissionGateway {
  Future<PermState> check(OnboardingPermission p);
  Future<PermState> request(OnboardingPermission p);
  Future<void> openSettings(OnboardingPermission p);

  /// "Health Connect" on Android, "Apple Health" on iPhone.
  String get healthName;
}

class PlatformOnboardingPermissions implements OnboardingPermissionGateway {
  const PlatformOnboardingPermissions();

  static bool get _isIOS {
    try {
      return !kIsWeb && Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  String get healthName => _isIOS ? 'Apple Health' : 'Health Connect';

  static PermState _step(StepPermission s) => switch (s) {
    StepPermission.granted || StepPermission.notRequired => PermState.granted,
    StepPermission.permanentlyDenied => PermState.permanentlyDenied,
    StepPermission.denied => PermState.notAsked,
  };

  static PermState _loc(LocationPermission p) => switch (p) {
    LocationPermission.whileInUse ||
    LocationPermission.always => PermState.granted,
    LocationPermission.deniedForever => PermState.permanentlyDenied,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => PermState.notAsked,
  };

  @override
  Future<PermState> check(OnboardingPermission p) async {
    try {
      switch (p) {
        case OnboardingPermission.activity:
          return _step(await MethodChannelStepPermission().status());
        case OnboardingPermission.location:
          return _loc(await Geolocator.checkPermission());
        case OnboardingPermission.health:
          final r = PlatformHealthReader.instance;
          if (!await r.isAvailable()) return PermState.unavailable;
          return await r.hasPermissions()
              ? PermState.granted
              : PermState.notAsked;
      }
    } catch (_) {
      return PermState.unavailable;
    }
  }

  @override
  Future<PermState> request(OnboardingPermission p) async {
    try {
      switch (p) {
        case OnboardingPermission.activity:
          // The existing path: asks, then starts counting when allowed.
          final r = await StepCounterService.instance.requestPermission();
          return switch (r) {
            StepPermission.granted ||
            StepPermission.notRequired => PermState.granted,
            StepPermission.permanentlyDenied => PermState.permanentlyDenied,
            StepPermission.denied => PermState.denied,
          };
        case OnboardingPermission.location:
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          final s = _loc(perm);
          return s == PermState.notAsked ? PermState.denied : s;
        case OnboardingPermission.health:
          final r = PlatformHealthReader.instance;
          if (!await r.isAvailable()) return PermState.unavailable;
          return await r.requestPermissions()
              ? PermState.granted
              : PermState.denied;
      }
    } catch (_) {
      return PermState.unavailable;
    }
  }

  @override
  Future<void> openSettings(OnboardingPermission p) async {
    try {
      switch (p) {
        case OnboardingPermission.activity:
          await StepCounterService.instance.openSettings();
        case OnboardingPermission.location:
          await Geolocator.openAppSettings();
        case OnboardingPermission.health:
          break;
      }
    } catch (_) {}
  }
}

/// The onboarding page that introduces each permission before the system
/// dialog. Atlas's own cards explain why; the system dialog itself is the
/// platform's and is not imitated. Every permission is optional.
class OnboardingPermissionsStep extends StatefulWidget {
  const OnboardingPermissionsStep({
    super.key,
    this.gateway = const PlatformOnboardingPermissions(),
  });

  final OnboardingPermissionGateway gateway;

  @override
  State<OnboardingPermissionsStep> createState() =>
      _OnboardingPermissionsStepState();
}

class _OnboardingPermissionsStepState extends State<OnboardingPermissionsStep> {
  final Map<OnboardingPermission, PermState> _state = {
    for (final p in OnboardingPermission.values) p: PermState.notAsked,
  };
  final Set<OnboardingPermission> _busy = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Shows what is already granted or refused, without asking for anything.
  Future<void> _refresh() async {
    for (final p in OnboardingPermission.values) {
      final s = await widget.gateway.check(p);
      if (!mounted) return;
      setState(() => _state[p] = s);
    }
  }

  Future<void> _ask(OnboardingPermission p) async {
    if (_busy.contains(p)) return;
    setState(() => _busy.add(p));
    final s = await widget.gateway.request(p);
    if (!mounted) return;
    setState(() {
      _busy.remove(p);
      _state[p] = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gateway;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeader(
            eyebrow: 'OPTIONAL',
            title: 'Let Atlas use your phone',
            subtitle:
                'Each of these switches on one feature. Atlas works without '
                'them, and you can change your mind at any time.',
          ),
          const SizedBox(height: 22),
          _PermissionCard(
            key: const Key('perm_activity'),
            icon: Icons.directions_walk_rounded,
            title: 'Physical activity',
            why:
                'Counts your steps with the phone\'s own step counter. '
                'Without it, steps show as unavailable.',
            state: _state[OnboardingPermission.activity]!,
            busy: _busy.contains(OnboardingPermission.activity),
            allowLabel: 'Allow step counting',
            onAllow: () => _ask(OnboardingPermission.activity),
            onSettings: () => g.openSettings(OnboardingPermission.activity),
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            key: const Key('perm_location'),
            icon: Icons.my_location_rounded,
            title: 'Location',
            why:
                'Draws your route and measures distance for outdoor runs and '
                'rides. Used only while you record one.',
            state: _state[OnboardingPermission.location]!,
            busy: _busy.contains(OnboardingPermission.location),
            allowLabel: 'Allow location',
            onAllow: () => _ask(OnboardingPermission.location),
            onSettings: () => g.openSettings(OnboardingPermission.location),
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            key: const Key('perm_health'),
            icon: Icons.favorite_rounded,
            title: g.healthName,
            why:
                'Reads the steps, sleep and heart rate your watch or other '
                'apps already saved, for better recovery insight. You pick '
                'what to share.',
            state: _state[OnboardingPermission.health]!,
            busy: _busy.contains(OnboardingPermission.health),
            allowLabel: 'Connect ${g.healthName}',
            onAllow: () => _ask(OnboardingPermission.health),
            onSettings: null,
            unavailableText: '${g.healthName} is not available on this phone.',
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: context.appTextMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can skip all of this. Allow or change any of it later '
                  'in your phone\'s Settings, or from the Health and Cardio '
                  'screens.',
                  key: const Key('perm_footer'),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.appTextMuted,
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.why,
    required this.state,
    required this.busy,
    required this.allowLabel,
    required this.onAllow,
    required this.onSettings,
    this.unavailableText,
  });

  final IconData icon;
  final String title;
  final String why;
  final PermState state;
  final bool busy;
  final String allowLabel;
  final VoidCallback onAllow;
  final VoidCallback? onSettings;
  final String? unavailableText;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final accent = context.appPrimary;
    final granted = state == PermState.granted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [Colors.white, Colors.white.withValues(alpha: 0.75)],
        ),
        border: Border.all(
          color: granted
              ? accent.withValues(alpha: 0.6)
              : (dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : context.appOutlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      why,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _action(context, accent),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, Color accent) {
    switch (state) {
      case PermState.granted:
        return _status(
          context,
          Icons.check_circle_rounded,
          'Allowed',
          accent,
          key: const Key('perm_status_granted'),
        );
      case PermState.unavailable:
        return _status(
          context,
          Icons.info_outline_rounded,
          unavailableText ?? 'Not available on this phone.',
          context.appTextMuted,
          key: const Key('perm_status_unavailable'),
        );
      case PermState.permanentlyDenied:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _status(
              context,
              Icons.block_rounded,
              'Not allowed. Android will not ask again; you can turn it on in '
              'Settings.',
              context.appTextSecondary,
              key: const Key('perm_status_blocked'),
            ),
            if (onSettings != null)
              TextButton(
                key: const Key('perm_open_settings'),
                onPressed: onSettings,
                child: const Text('Open Settings'),
              ),
          ],
        );
      case PermState.denied:
      case PermState.notAsked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state == PermState.denied)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _status(
                  context,
                  Icons.info_outline_rounded,
                  'Not allowed. That is fine; you can allow it later.',
                  context.appTextSecondary,
                  key: const Key('perm_status_denied'),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: Key('allow_$allowLabel'),
                onPressed: busy ? null : onAllow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Text(
                        state == PermState.denied ? 'Try again' : allowLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        );
    }
  }

  Widget _status(
    BuildContext context,
    IconData icon,
    String text,
    Color color, {
    Key? key,
  }) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
