import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class ProfileImage extends StatelessWidget {
  final String? path;
  final double size;
  final double iconSize;

  const ProfileImage({
    super.key,
    required this.path,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1,
        ),
        color: AppColors.surfaceContainer,
      ),
      child: ClipOval(
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return Icon(
        Icons.person,
        size: iconSize,
        color: AppColors.primary,
      );
    }

    if (path!.startsWith('http://') ||
        path!.startsWith('https://') ||
        path!.startsWith('blob:')) {
      return Image.network(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.person,
          size: iconSize,
          color: AppColors.primary,
        ),
      );
    }

    if (path!.startsWith('assets/')) {
      return Image.asset(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.person,
          size: iconSize,
          color: AppColors.primary,
        ),
      );
    }

    if (!kIsWeb) {
      try {
        return Image.file(
          File(path!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person,
            size: iconSize,
            color: AppColors.primary,
          ),
        );
      } catch (_) {
        return Icon(
          Icons.person,
          size: iconSize,
          color: AppColors.primary,
        );
      }
    }

    return Icon(
      Icons.person,
      size: iconSize,
      color: AppColors.primary,
    );
  }
}
