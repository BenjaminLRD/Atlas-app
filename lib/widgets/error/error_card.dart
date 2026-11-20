import 'package:flutter/material.dart';
import 'error_message_mapper.dart';
import 'retry_button.dart';

/// Bento-style, responsive error display card presenting friendly guidance
/// and a retry recovery trigger.
class ErrorCard extends StatelessWidget {
  final Object? error;
  final String? customTitle;
  final String? customMessage;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorCard({
    super.key,
    this.error,
    this.customTitle,
    this.customMessage,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapped = ErrorMessageMapper.map(error);
    final title = customTitle ?? mapped.title;
    final message = customMessage ?? mapped.message;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            RetryButton(onRetry: onRetry!),
          ],
        ],
      ),
    );
  }
}
