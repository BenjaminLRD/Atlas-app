import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Standardized, user-friendly error recovery widget providing clear explanations,
/// a retry trigger, and an optional fallback action to prevent blank screens or dead ends.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final VoidCallback? onFallback;
  final String retryButtonText;
  final String? fallbackButtonText;

  const ErrorStateWidget({
    super.key,
    this.title = 'Something Went Wrong',
    this.message =
        'We encountered an unexpected issue while processing your request. Please try again.',
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.onFallback,
    this.retryButtonText = 'Try Again',
    this.fallbackButtonText,
  });

  /// Factory for AI Coach / Vision Service unavailability
  factory ErrorStateWidget.aiUnavailable({
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onUseOffline,
  }) {
    return ErrorStateWidget(
      key: key,
      title: 'AI Coach Temporarily Offline',
      message:
          'Unable to connect to the cloud AI service. You can retry or continue with offline coaching.',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
      onFallback: onUseOffline,
      retryButtonText: 'Retry Connection',
      fallbackButtonText: onUseOffline != null ? 'Use Offline Coach' : null,
    );
  }

  /// Factory for Food Scanner failures / unconfident scans
  factory ErrorStateWidget.scannerFailure({
    Key? key,
    VoidCallback? onRetryScan,
    VoidCallback? onManualSearch,
    String? customMessage,
  }) {
    return ErrorStateWidget(
      key: key,
      title: 'Food Recognition Issue',
      message:
          customMessage ??
          'Could not confidently identify the food item. Try scanning with better lighting or search manually.',
      icon: Icons.camera_enhance_rounded,
      onRetry: onRetryScan,
      onFallback: onManualSearch,
      retryButtonText: 'Scan Again',
      fallbackButtonText: onManualSearch != null
          ? 'Search Food Database'
          : null,
    );
  }

  /// Factory for Network / Cloud Sync connectivity failures
  factory ErrorStateWidget.networkFailure({
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onContinueOffline,
  }) {
    return ErrorStateWidget(
      key: key,
      title: 'No Internet Connection',
      message:
          'Your progress is saved locally and will automatically synchronize when you are back online.',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
      onFallback: onContinueOffline,
      retryButtonText: 'Retry Sync',
      fallbackButtonText: onContinueOffline != null ? 'Continue Offline' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    retryButtonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              if (onFallback != null && fallbackButtonText != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onFallback,
                  child: Text(
                    fallbackButtonText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
