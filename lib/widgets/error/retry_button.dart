import 'package:flutter/material.dart';

/// Clean, responsive retry button widget with loading state and tap feedback.
class RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final String label;
  final bool isLoading;
  final IconData icon;

  const RetryButton({
    super.key,
    required this.onRetry,
    this.label = 'Try Again',
    this.isLoading = false,
    this.icon = Icons.refresh_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onRetry,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        isLoading ? 'Retrying...' : label,
        style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
