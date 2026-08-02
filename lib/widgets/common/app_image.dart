import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Scalable, unified remote and asset image widget for Aizawl Gym.
/// Handles remote URLs, asset fallbacks, loading states, and failed load fallbacks
/// cleanly across web and mobile platforms.
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final IconData fallbackIcon;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadii.lg,
    this.fallbackIcon = Icons.fitness_center_rounded,
    this.fallbackText,
    this.backgroundColor,
    this.iconColor,
  });

  /// Factory constructor optimized for user profile avatars
  factory AppImage.avatar({
    Key? key,
    String? imageUrl,
    String? assetPath,
    double radius = 24.0,
    String? name,
  }) {
    return AppImage(
      key: key,
      imageUrl: imageUrl,
      assetPath: assetPath,
      width: radius * 2,
      height: radius * 2,
      borderRadius: radius,
      fallbackIcon: Icons.person_rounded,
      fallbackText: name,
    );
  }

  /// Factory constructor optimized for exercise cards
  factory AppImage.exercise({
    Key? key,
    String? imageUrl,
    String? assetPath,
    double size = 76.0,
    String? exerciseName,
  }) {
    return AppImage(
      key: key,
      imageUrl: imageUrl,
      assetPath: assetPath,
      width: size,
      height: size,
      borderRadius: AppRadii.lg,
      fallbackIcon: Icons.fitness_center_rounded,
      fallbackText: exerciseName,
    );
  }

  String? _sanitizeAssetPath(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('assets/assets/')) {
      return path.replaceFirst('assets/assets/', 'assets/');
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? context.appCardBg;
    final effectiveIconColor = iconColor ?? AppColors.primaryContainer;
    final sanitizedAsset = _sanitizeAssetPath(assetPath);

    Widget content;

    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      content = Image.network(
        imageUrl!.trim(),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingWidget(context, effectiveBg);
        },
        errorBuilder: (context, error, stackTrace) {
          if (sanitizedAsset != null) {
            return _buildAssetImage(context, sanitizedAsset, effectiveBg, effectiveIconColor);
          }
          return _buildFallbackWidget(context, effectiveBg, effectiveIconColor);
        },
      );
    } else if (sanitizedAsset != null) {
      content = _buildAssetImage(context, sanitizedAsset, effectiveBg, effectiveIconColor);
    } else {
      content = _buildFallbackWidget(context, effectiveBg, effectiveIconColor);
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: content,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: content,
    );
  }

  Widget _buildAssetImage(
    BuildContext context,
    String path,
    Color bg,
    Color iconColor,
  ) {
    final String cleanKey =
        path.startsWith('assets/') ? path.replaceFirst('assets/', '') : path;

    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          cleanKey,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackWidget(context, bg, iconColor);
          },
        );
      },
    );
  }

  Widget _buildLoadingWidget(BuildContext context, Color bg) {
    return Container(
      width: width,
      height: height,
      color: bg,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryContainer.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackWidget(
    BuildContext context,
    Color bg,
    Color iconColor,
  ) {
    final initial = (fallbackText != null && fallbackText!.trim().isNotEmpty)
        ? fallbackText!.trim()[0].toUpperCase()
        : null;

    return Container(
      width: width,
      height: height,
      color: bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            fallbackIcon,
            color: iconColor,
            size: (width != null && width! < 50) ? 18 : 26,
          ),
          if (initial != null && (width == null || width! >= 60)) ...[
            const SizedBox(height: 2),
            Text(
              initial,
              style: AppTheme.bodySm.copyWith(
                fontWeight: FontWeight.bold,
                color: iconColor,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
