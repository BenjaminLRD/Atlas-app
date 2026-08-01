import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_button.dart';

/// Unified Design System Dialog Helper (`AppDialog.show(...)`).
class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) {
        return ClipRRect(
          borderRadius: AppRadii.borderXl,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AlertDialog(
              backgroundColor: context.appSurface.withValues(alpha: context.isDarkMode ? 0.88 : 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderXl,
            side: BorderSide(
              color: context.appOutlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: Text(
            title,
            style: AppTheme.headlineLg.copyWith(
              fontSize: 18,
              color: context.appTextPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: content,
          ),
          actions: actions ??
              [
                AppButton.text(
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
        ),
      ),
    );
  },
);
  }
}
