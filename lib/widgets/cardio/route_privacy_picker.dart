import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/cardio_activity_data.dart';
import '../../services/cardio/route_privacy.dart';
import '../../services/community/cardio_post_publisher.dart';
import 'route_map_view.dart';

/// Lets the athlete choose how much of their route is shared, explains each
/// choice in plain words, and previews exactly what others will see.
class RoutePrivacyPicker extends StatelessWidget {
  const RoutePrivacyPicker({
    super.key,
    required this.data,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final CardioActivityData data;
  final RoutePrivacyMode mode;
  final ValueChanged<RoutePrivacyMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final masked = CardioPostPublisher.maskedRoute(data, mode);
    final hasOriginal = data.route.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who can see where you went',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Posts in Community can be seen by other members. Your own saved '
          'activity always keeps the full route.',
          style: AppTheme.bodySm.copyWith(
            fontSize: 11.5,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final m in RoutePrivacyMode.values)
          InkWell(
            key: Key('privacy_${m.name}'),
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onChanged(m) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    m == mode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: m == mode
                        ? AppColors.primary
                        : context.appTextSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: m == mode
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          mode.explanation,
          key: const Key('privacy_explanation'),
          style: AppTheme.bodySm.copyWith(
            fontSize: 12,
            color: context.appTextSecondary,
          ),
        ),
        if (hasOriginal) ...[
          const SizedBox(height: 10),
          Text(
            'What others will see',
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          RouteMapView(
            key: const Key('privacy_preview'),
            route: masked.route,
            height: 130,
            borderRadius: 14,
            emptyMessage: masked.tooShortToHide
                ? 'Too short to hide safely, so no route will be shared'
                : 'No route will be shared',
          ),
        ],
      ],
    );
  }
}
