import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../models/food_item.dart';
import '../../models/nutrient_format.dart';
import '../../services/nutrition/nutrition_calculator.dart';

/// Colours and small building blocks shared by the food scanner results (the
/// AI photo estimate and the scanned-product sheet), so both read as one
/// design: charcoal surfaces, hairline borders, and green kept for the
/// primary action.
class FoodResultStyle {
  FoodResultStyle._();

  static const Color surface = Color(0xFF15171D);
  static const Color raised = Color(0xFF1C1F27);
  static const Color hairline = Color(0x14FFFFFF);
  static const Color text = Color(0xFFF2F4F7);
  static const Color muted = Color(0xFF98A2B3);
  static const Color caution = Color(0xFFE5B64B);
  static const Color danger = Color(0xFFE5736B);

  static const Color protein = Color(0xFF34C77B);
  static const Color carbs = Color(0xFF6C9EF8);
  static const Color fat = Color(0xFFE9A94F);

  static const Color accent = AppColors.primaryContainer;

  static TextStyle title({double size = 22}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: text,
    height: 1.15,
    letterSpacing: -0.2,
  );

  static TextStyle body({
    double size = 12,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.35);
}

/// Where the numbers come from. Only [database] means data that someone
/// entered for the product; an AI photo estimate is never presented as that.
enum FoodSourceKind {
  /// Product database (Open Food Facts).
  database,

  /// Typed in by the user.
  userEntry,

  /// Estimated by AI from a photo; not checked against anything.
  aiEstimate,

  /// An AI estimate whose own confidence was low.
  aiLow,

  /// No nutrition data at all.
  unavailable,
}

/// A small pill that says where the nutrition comes from.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.kind, this.label, this.textKey});

  final FoodSourceKind kind;

  /// Key of the label text, for tests.
  final Key? textKey;

  /// Overrides the default wording.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color tint) = switch (kind) {
      FoodSourceKind.database => (
        Icons.fact_check_outlined,
        'Product database',
        FoodResultStyle.accent,
      ),
      FoodSourceKind.userEntry => (
        Icons.edit_note_rounded,
        'Entered by you',
        FoodResultStyle.carbs,
      ),
      FoodSourceKind.aiEstimate => (
        Icons.auto_awesome_rounded,
        'Unverified AI estimate',
        FoodResultStyle.caution,
      ),
      FoodSourceKind.aiLow => (
        Icons.auto_awesome_rounded,
        'Low confidence • check it',
        FoodResultStyle.danger,
      ),
      FoodSourceKind.unavailable => (
        Icons.help_outline_rounded,
        'Nutrition unavailable',
        FoodResultStyle.muted,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label ?? text,
              key: textKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tint,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The calories, large, with a quiet unit. [value] is the number as shown
/// (for example "~207", "120" or an em dash when unknown).
class CalorieHero extends StatelessWidget {
  const CalorieHero({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: FoodResultStyle.text,
              height: 1.0,
              letterSpacing: -0.8,
            ),
          ),
          const TextSpan(
            text: ' kcal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FoodResultStyle.muted,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One macro for [MacroStrip]. A null [grams] means the value is unknown.
class MacroEntry {
  const MacroEntry(this.label, this.grams, this.color, {this.energyPerGram});

  final String label;
  final double? grams;
  final Color color;

  /// kcal per gram, for the proportion bar.
  final double? energyPerGram;
}

/// Protein, carbohydrates and fat side by side, with a thin bar showing how
/// the calories are split (only when all three are known).
class MacroStrip extends StatelessWidget {
  const MacroStrip({super.key, required this.entries, this.prefix = ''});

  final List<MacroEntry> entries;

  /// Put before each value, for example "~" for an estimate.
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final known = entries.every((e) => e.grams != null);
    final energies = [
      for (final e in entries) (e.grams ?? 0) * (e.energyPerGram ?? 0),
    ];
    final total = energies.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final e in entries)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: e.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FoodResultStyle.body(size: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.grams == null
                          ? '—'
                          : '$prefix${e.grams!.toStringAsFixed(1)}g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FoodResultStyle.text,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (known && total > 0) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    if (energies[i] > 0)
                      Expanded(
                        flex: (energies[i] / total * 1000).round().clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(
                          color: entries[i].color.withValues(alpha: 0.85),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Portion: ~450 ml" with an obvious Edit control.
class ServingRow extends StatelessWidget {
  const ServingRow({
    super.key,
    required this.value,
    required this.onEdit,
    this.editKey,
    this.editLabel = 'Edit',
  });

  /// The portion as shown, for example "~450 ml" or "100 g".
  final String value;
  final VoidCallback onEdit;
  final Key? editKey;

  /// The button's text: "Confirm" while the amount is only a guess.
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.restaurant_rounded,
          size: 15,
          color: FoodResultStyle.muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Portion: ',
                  style: FoodResultStyle.body(size: 13),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FoodResultStyle.text,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          key: editKey,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 14),
          label: Text(editLabel),
          style: TextButton.styleFrom(
            foregroundColor: FoodResultStyle.accent,
            backgroundColor: FoodResultStyle.accent.withValues(alpha: 0.10),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sugar, fibre, saturated fat, salt and sodium for the amount shown: each is
/// its value, or a dash when the source does not give it (never a made-up 0).
class MoreNutrients extends StatelessWidget {
  const MoreNutrients({super.key, required this.food, required this.scaled});

  final FoodItem food;
  final ScaledNutrition scaled;

  @override
  Widget build(BuildContext context) {
    String entry(String label, String nutrient, double? value, String unit) {
      final text = NutrientFormat.grams(
        value,
        food.statusOf(nutrient),
        digits: nutrient == FoodItem.saltKey ? 2 : 1,
        unit: unit,
      );
      return '$label $text';
    }

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final line in [
          entry('Sugar', FoodItem.sugarKey, scaled.sugar, 'g'),
          entry('Fibre', FoodItem.fiberKey, scaled.fiber, 'g'),
          entry('Sat. fat', FoodItem.saturatedFatKey, scaled.saturatedFat, 'g'),
          entry('Salt', FoodItem.saltKey, scaled.salt, 'g'),
          entry('Sodium', FoodItem.sodiumKey, scaled.sodium, 'mg'),
        ])
          Text(line, style: FoodResultStyle.body(size: 11.5)),
      ],
    );
  }
}

/// Where the numbers come from, for a food that came from Open Food Facts: the
/// source, the product page (tap to open), when it was retrieved, and a
/// reminder that the data is community-contributed. Nothing for other
/// sources. A record being found is not a guarantee that it is right.
class SourceNote extends StatelessWidget {
  const SourceNote({super.key, required this.food, this.textKey});

  final FoodItem food;
  final Key? textKey;

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to open the link with: the product number is still shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = food.sourceUrl;
    if (food.nutritionSource != NutritionSource.openFoodFacts || url == null) {
      return const SizedBox.shrink();
    }
    final retrieved = food.sourceRetrievedAt;
    return InkWell(
      onTap: () => _open(url),
      child: NoticeLine(
        icon: Icons.link_rounded,
        color: FoodResultStyle.accent,
        textKey: textKey,
        text:
            'Source: Open Food Facts, product ${url.split('/').last}'
            '${retrieved == null ? '' : ', retrieved ${_date(retrieved)}'}. '
            'Community-contributed data (Open Database License): it can be '
            'incomplete or inaccurate. Tap to open.',
      ),
    );
  }
}

/// A calm amber box for notes the user should read before logging.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.children, this.tint});

  final List<Widget> children;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? FoodResultStyle.caution;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// A line of text with a small leading icon, for [NoticeBox].
class NoticeLine extends StatelessWidget {
  const NoticeLine({
    super.key,
    required this.icon,
    required this.text,
    this.textKey,
    this.color,
  });

  final IconData icon;
  final String text;
  final Key? textKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? FoodResultStyle.caution;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: c),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: textKey,
            style: FoodResultStyle.body(
              size: 11.5,
              color: FoodResultStyle.text.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }
}

/// Asks before a food whose calories are unknown is logged. Logging it is
/// allowed, but it counts as 0 kcal in the totals and stays marked unknown.
/// True when the user chose to log it anyway.
Future<bool> confirmLogUnknownCalories(
  BuildContext context,
  String foodName,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Calories unknown'),
      content: Text(
        '$foodName has no calories in the database. If you log it, it counts '
        'as 0 kcal in your totals but stays marked as unknown. Its other '
        'values are kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Log anyway'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The primary (filled, green) and secondary (quiet) buttons of the results.
class ResultButtons {
  ResultButtons._();

  static ButtonStyle primary() => FilledButton.styleFrom(
    backgroundColor: FoodResultStyle.accent,
    foregroundColor: Colors.black,
    minimumSize: const Size.fromHeight(50),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  static ButtonStyle secondary() => OutlinedButton.styleFrom(
    foregroundColor: FoodResultStyle.text,
    backgroundColor: FoodResultStyle.raised,
    side: const BorderSide(color: FoodResultStyle.hairline),
    minimumSize: const Size.fromHeight(50),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
