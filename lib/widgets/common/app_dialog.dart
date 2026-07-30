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
        return AlertDialog(
          backgroundColor: context.appSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
        );
      },
    );
  }
}
