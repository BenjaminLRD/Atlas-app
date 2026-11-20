import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/recipe.dart';
import '../../screens/checkout_screen.dart' show GlassPanel;
import '../../services/recipes/recipe_ratings.dart';
import '../profile_picture.dart';

/// "310" / "--" for unknown; a trailing "+" when some ingredients had no value.
String recipeNumber(double? v, {bool partial = false}) =>
    v == null ? '--' : '${v.round()}${partial ? '+' : ''}';

/// The recipe's photo: a bundled image, a photo the athlete added, or a plain
/// tile when there is none (never another recipe's picture).
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.recipe,
    this.width,
    this.height,
    this.radius = 18,
  });

  final Recipe recipe;
  final double? width;
  final double? height;
  final double radius;

  Widget _fallback(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.appPrimary.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
    ),
    child: Icon(
      Icons.restaurant_rounded,
      color: context.appPrimary.withValues(alpha: 0.7),
      size: 32,
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (recipe.imageAsset != null) {
      child = Image.asset(
        recipe.imageAsset!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: recipe.name,
        errorBuilder: (c, _, _) => _fallback(c),
      );
    } else if (recipe.imageFile != null && !kIsWeb) {
      child = Image.file(
        File(recipe.imageFile!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: recipe.name,
        errorBuilder: (c, _, _) => _fallback(c),
      );
    } else {
      child = _fallback(context);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

/// A recipe in a list: photo, name, short description, time, calories and
/// protein up front with carbs and fat beside them, rating, and a bookmark.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.rating,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  final Recipe recipe;
  final RatingSummary rating;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final n = recipe.perServing;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RecipeImage(recipe: recipe, width: 96, height: 112),
                if (recipe.isSample)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      key: Key('sample_badge_${recipe.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'SAMPLE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          key: Key('save_${recipe.id}'),
                          padding: EdgeInsets.zero,
                          tooltip: saved ? 'Remove from saved' : 'Save recipe',
                          onPressed: onToggleSaved,
                          icon: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: saved
                                ? context.appPrimary
                                : context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (recipe.creatorName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (recipe.creatorAvatar != null)
                          ProfileImage(
                            path: recipe.creatorAvatar,
                            size: 18,
                            iconSize: 11,
                          ),
                        if (recipe.creatorAvatar != null)
                          const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            recipe.creatorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _meta(
                        context,
                        Icons.schedule_rounded,
                        '${recipe.prepMinutes} min',
                      ),
                      _meta(
                        context,
                        Icons.star_rounded,
                        rating.label,
                        color: rating.hasRatings
                            ? const Color(0xFFFBBF24)
                            : null,
                        key: Key('rating_${recipe.id}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _badge(
                        context,
                        '${recipeNumber(n.calories, partial: n.partial)} kcal',
                        strong: true,
                      ),
                      _badge(
                        context,
                        'P ${recipeNumber(n.protein, partial: n.partial)} g',
                        strong: true,
                      ),
                      _badge(
                        context,
                        'C ${recipeNumber(n.carbs, partial: n.partial)} g',
                      ),
                      _badge(
                        context,
                        'F ${recipeNumber(n.fat, partial: n.partial)} g',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
    Key? key,
  }) {
    final c = color ?? context.appTextSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            key: key,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(BuildContext context, String text, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong
            ? context.appPrimary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: context.isDarkMode ? 0.06 : 0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: strong
              ? context.appPrimary.withValues(alpha: 0.5)
              : context.appOutlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? context.appPrimary : context.appTextSecondary,
        ),
      ),
    );
  }
}
