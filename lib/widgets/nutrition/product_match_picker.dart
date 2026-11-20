import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../services/food/off_search_client.dart';
import 'food_result_parts.dart';

/// A list of database products that may be the one in the photo. Nothing is
/// chosen for the user: each row shows the pack size and whether the record
/// has nutrition facts, so they can tell sizes apart.
class ProductMatchPicker extends StatelessWidget {
  const ProductMatchPicker({
    super.key,
    required this.title,
    required this.candidates,
    required this.onSelected,
    this.onDismiss,
    this.dismissLabel = 'None of these — keep AI estimate',
  });

  final String title;
  final List<OffProduct> candidates;
  final ValueChanged<OffProduct> onSelected;

  /// Shown as a quiet button under the list when set.
  final VoidCallback? onDismiss;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FoodResultStyle.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FoodResultStyle.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FoodResultStyle.title(size: 16)),
          const SizedBox(height: 4),
          Text(
            'Pick the one that matches your pack. Check the size.',
            style: FoodResultStyle.body(size: 12),
          ),
          const SizedBox(height: 8),
          for (final p in candidates) _tile(p),
          if (onDismiss != null)
            TextButton(
              key: const Key('product_candidates_dismiss'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: FoodResultStyle.muted,
                minimumSize: const Size(0, 44),
              ),
              child: Text(dismissLabel, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  static String _nutritionText(OffProduct p) {
    final f = p.food;
    if (!f.isNutrientKnown(FoodItem.calorieKey)) return 'no nutrition data';
    final per = switch (f.nutritionBasis) {
      NutritionBasis.per100ml => 'per 100 ml',
      NutritionBasis.per100g => 'per 100 g',
      NutritionBasis.perServing => 'per serving',
      NutritionBasis.perPackage => 'per package',
      NutritionBasis.unknown => 'per 100 g/ml',
    };
    return '${f.calories.round()} kcal $per';
  }

  Widget _tile(OffProduct p) {
    final details = [
      if (p.brands.isNotEmpty) p.brands.first,
      p.sizeLabel ?? 'size not stated',
      _nutritionText(p),
      if (!p.inIndia) 'Not listed for India',
    ].join(' • ');
    return InkWell(
      key: Key('product_candidate_${p.code}'),
      onTap: () => onSelected(p),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FoodResultStyle.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FoodResultStyle.body(size: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: FoodResultStyle.muted,
            ),
          ],
        ),
      ),
    );
  }
}
