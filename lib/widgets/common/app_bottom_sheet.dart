import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Unified Design System Modal Bottom Sheet Helper.
class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: context.appSurface.withValues(alpha: context.isDarkMode ? 0.88 : 0.92),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Bar
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
                        const SizedBox(height: 16),

                        // Title & Close Button Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTheme.headlineLg.copyWith(
                                      fontSize: 18,
                                      color: context.appTextPrimary,
                                    ),
                                  ),
                                  if (subtitle != null && subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 12,
                                        color: context.appTextSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: context.appSurfaceElevated,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 18),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Sheet Content Body
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
