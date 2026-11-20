import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// Charcoal page with one soft emerald glow at the top, the shared backdrop of
/// every onboarding screen. A static gradient: no blur, no animation cost.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.15),
                  radius: 1.1,
                  colors: [
                    context.appPrimary.withValues(alpha: dark ? 0.16 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Round back button, a thin segmented progress bar, and "STEP n OF m".
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({
    super.key,
    required this.step,
    required this.total,
    required this.onBack,
  });

  /// 1-based step shown, out of [total].
  final int step;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 6),
      child: Row(
        children: [
          Material(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.07)
                : context.appSurfaceElevated,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('onboarding_back'),
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: context.appTextPrimary,
                  semanticLabel: 'Back',
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $step OF $total',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 1; i <= total; i++) ...[
                      if (i > 1) const SizedBox(width: 4),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: i <= step
                                ? accent
                                : context.appOutlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small label chip, a large title and a muted description. Used at the top
/// of each step so they all read the same way.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.appPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              eyebrow!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: context.appPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: AppTheme.headlineLg.copyWith(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTheme.bodyMd.copyWith(
            fontSize: 14.5,
            height: 1.4,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}
