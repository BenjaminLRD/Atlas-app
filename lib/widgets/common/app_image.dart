import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Scalable, unified remote and asset image widget for Atlas.
/// Handles remote URLs, asset fallbacks, loading states, and failed load fallbacks
/// cleanly across web and mobile platforms using cached network images.
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
  final Widget? customFallback;

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
    this.customFallback,
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
    IconData fallbackIcon = Icons.fitness_center_rounded,
    Widget? customFallback,
  }) {
    return AppImage(
      key: key,
      imageUrl: imageUrl,
      assetPath: assetPath,
      width: size,
      height: size,
      borderRadius: AppRadii.lg,
      fallbackIcon: fallbackIcon,
      fallbackText: exerciseName,
      customFallback: customFallback,
    );
  }

  /// Factory constructor optimized for motivational quotes and character artwork
  factory AppImage.quote({
    Key? key,
    String? imageUrl,
    String? assetPath,
    double? width,
    double? height,
    double borderRadius = 18.0,
    String? characterName,
  }) {
    return AppImage(
      key: key,
      imageUrl: imageUrl,
      assetPath: assetPath,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fallbackIcon: Icons.format_quote_rounded,
      fallbackText: characterName,
    );
  }

  /// True for a path on the device (for example a gallery pick), as opposed to
  /// a web address, an asset or a blob. Such a path cannot go through the
  /// network image loader.
  static bool isLocalFilePath(String path) {
    final p = path.trim();
    if (p.isEmpty) return false;
    final lower = p.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('blob:') ||
        lower.startsWith('data:') ||
        lower.startsWith('assets/')) {
      return false;
    }
    return true;
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

    if (imageUrl != null && isLocalFilePath(imageUrl!) && !kIsWeb) {
      // A photo picked from the gallery is a file on the phone, not a URL.
      content = Image.file(
        File(imageUrl!.trim()),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          if (sanitizedAsset != null) {
            return _buildAssetImage(
              context,
              sanitizedAsset,
              effectiveBg,
              effectiveIconColor,
            );
          }
          return _buildFallbackWidget(context, effectiveBg, effectiveIconColor);
        },
      );
    } else if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: imageUrl!.trim(),
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            _buildLoadingWidget(context, effectiveBg),
        errorWidget: (context, url, error) {
          if (sanitizedAsset != null) {
            return _buildAssetImage(
              context,
              sanitizedAsset,
              effectiveBg,
              effectiveIconColor,
            );
          }
          return _buildFallbackWidget(context, effectiveBg, effectiveIconColor);
        },
      );
    } else if (sanitizedAsset != null) {
      content = _buildAssetImage(
        context,
        sanitizedAsset,
        effectiveBg,
        effectiveIconColor,
      );
    } else {
      content = _buildFallbackWidget(context, effectiveBg, effectiveIconColor);
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(width: width, height: height, child: content),
      );
    }

    return SizedBox(width: width, height: height, child: content);
  }

  Widget _buildAssetImage(
    BuildContext context,
    String path,
    Color bg,
    Color iconColor,
  ) {
    final String cleanKey = path.startsWith('assets/')
        ? path.replaceFirst('assets/', '')
        : path;

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
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackWidget(BuildContext context, Color bg, Color iconColor) {
    if (customFallback != null) {
      return customFallback!;
    }

    final showLabel =
        fallbackText != null &&
        fallbackText!.trim().isNotEmpty &&
        (width == null || width! >= 70) &&
        (height == null || height! >= 70);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, bg.withValues(alpha: 0.85)],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(
                  (width != null && width! < 60) ? 6 : 12,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  fallbackIcon,
                  color: iconColor,
                  size: (width != null && width! < 60) ? 18 : 34,
                ),
              ),
              if (showLabel) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    fallbackText!.trim().toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelCaps.copyWith(
                      fontWeight: FontWeight.w800,
                      color: iconColor,
                      fontSize: 11,
                      letterSpacing: 1.1,
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
