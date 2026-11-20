import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../models/meal_entry.dart';
import '../models/meal_prep.dart';
import '../models/recipe.dart';
import '../services/meal_prep_store.dart';
import '../services/nutrition/nutrition_service.dart';
import '../services/recipes/recipe_ratings.dart';
import '../services/recipes/recipe_stores.dart';
import '../widgets/profile_picture.dart';
import '../widgets/recipes/recipe_card.dart';
import 'checkout_screen.dart' show GlassPanel;

/// One recipe in full: photo, creator, rating, ingredients, steps, nutrition
/// per serving, reviews, and the actions to save it, add it to a meal plan or
/// log it to today's food diary.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.hub,
    this.nutrition,
    this.logger,
    this.saved,
    this.planStore,
  });

  final Recipe recipe;
  final RecipeHub? hub;
  final NutritionService? nutrition;
  final MealLogger? logger;
  final SavedRecipesStore? saved;
  final MealPrepStore? planStore;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final NutritionService _nutrition =
      widget.nutrition ?? AppDependencies.instance.nutritionService;
  late final RecipeHub _hub =
      widget.hub ?? RecipeHub(foods: _nutrition.getAvailableFoods());
  late final MealLogger _logger = widget.logger ?? MealLogger();
  late final SavedRecipesStore _savedStore =
      widget.saved ?? SavedRecipesStore();
  late double _servings = widget.recipe.servings.toDouble();

  Recipe get _r => widget.recipe;
  bool get _showcase => LocalStorage.isShowcaseModeEnabled();

  void _say(String m, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), action: action));
  }

  Future<void> _toggleSave() async {
    await _savedStore.toggle(_r.id);
    if (mounted) setState(() {});
  }

  // ---- rating -------------------------------------------------------------

  Future<void> _rate() async {
    final repo = _hub.ratings;
    if (!repo.available) {
      _say(repo.unavailableReason ?? 'Ratings are not available.');
      return;
    }
    final own = repo.mine(_r.id);
    final result = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RateSheet(
        initialStars: own?.stars ?? 0,
        initialReview: own?.review ?? '',
        updating: own != null,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await repo.submit(recipeId: _r.id, stars: result.$1, review: result.$2);
      if (mounted) {
        setState(() {});
        _say(own == null ? 'Thanks for rating.' : 'Your rating was updated.');
      }
    } on RatingException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  // ---- diary --------------------------------------------------------------

  Future<void> _logToDiary() async {
    if (_showcase) {
      _say(
        'Logging is switched off in Showcase Mode, so demo meals never '
        'touch a real food diary.',
      );
      return;
    }
    final choice = await showModalBottomSheet<(MealCategory, double)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PortionSheet(
        recipe: _r,
        title: 'Add to today\'s diary',
        confirmLabel: 'Add to diary',
        initialServings: 1,
        showDays: false,
      ),
    );
    if (choice == null || !mounted) return;
    final slot = choice.$1;
    final servings = choice.$2;
    try {
      final res = await _logger.log(_r, servings, slot, _nutrition);
      if (!mounted) return;
      if (res.alreadyLogged) {
        _say(
          'This meal is already in today\'s ${slot.name}.',
          action: SnackBarAction(
            label: 'Add again',
            onPressed: () async {
              final again = await _logger.log(
                _r,
                servings,
                slot,
                _nutrition,
                force: true,
              );
              if (mounted) {
                _say(
                  'Added ${again.added} item${again.added == 1 ? '' : 's'} again.',
                );
              }
            },
          ),
        );
      } else if (res.added == 0) {
        _say('Nothing could be added: these foods have no usable portion.');
      } else {
        _say(
          'Added to today\'s ${slot.name}'
          '${res.skipped > 0 ? ' (${res.skipped} item skipped)' : ''}.',
        );
      }
    } catch (_) {
      if (mounted) _say('Could not add to the diary. Nothing was changed.');
    }
  }

  // ---- plan ---------------------------------------------------------------

  Future<void> _addToPlan() async {
    final store = widget.planStore ?? MealPrepStore();
    final plans = store.all();
    final choice = await showModalBottomSheet<_PlanChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlanSheet(recipe: _r, plans: plans),
    );
    if (choice == null || !mounted) return;
    try {
      final saved = await RecipePlanner(store: store).add(
        _r,
        choice.servings,
        plan: choice.plan,
        newName: choice.plan == null ? _r.name : null,
        day: choice.day,
        slot: choice.slot,
      );
      if (mounted) _say('Added to "${saved.name}", day ${choice.day + 1}.');
    } catch (_) {
      if (mounted) _say('Could not add to the plan. Nothing was changed.');
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final summary = _hub.ratings.summaryFor(_r.id);
    final saved = _savedStore.isSaved(_r.id);
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 250,
                  backgroundColor: context.appBackground,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        RecipeImage(recipe: _r, radius: 0),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x66000000),
                                Colors.transparent,
                                Color(0xCC111418),
                              ],
                              stops: [0, 0.4, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context, summary),
                        const SizedBox(height: 16),
                        _servingsRow(context),
                        const SizedBox(height: 12),
                        _nutritionCard(context),
                        const SizedBox(height: 18),
                        _section(context, 'Ingredients'),
                        _ingredients(context),
                        const SizedBox(height: 18),
                        _section(context, 'Method'),
                        _steps(context),
                        const SizedBox(height: 18),
                        _section(context, 'Ratings and reviews'),
                        _reviews(context, summary),
                        if (_r.imageCredit != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Photo: ${_r.imageCredit}',
                            key: const Key('image_credit'),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: context.appTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _actionBar(context, saved),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, RatingSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _r.name,
                key: const Key('recipe_title'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            if (_r.isSample)
              Container(
                key: const Key('detail_sample_badge'),
                margin: const EdgeInsets.only(left: 8, top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appTextSecondary),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'SAMPLE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_r.creatorName != null) ...[
              if (_r.creatorAvatar != null)
                ProfileImage(path: _r.creatorAvatar, size: 24, iconSize: 14),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'By ${_r.creatorName}',
                  key: const Key('creator_name'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ] else
              Text(
                _r.origin == RecipeOrigin.atlas ? 'By Atlas' : 'Your meal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: summary.hasRatings
                      ? const Color(0xFFFBBF24)
                      : context.appTextMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    summary.hasRatings
                        ? '${summary.average!.toStringAsFixed(1)} '
                              '(${summary.count} rating${summary.count == 1 ? '' : 's'})'
                        : 'No ratings yet',
                    key: const Key('detail_rating'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 17,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_r.prepMinutes} min',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_r.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _r.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _servingsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Servings',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: const Key('servings_minus'),
          tooltip: 'Fewer servings',
          onPressed: _servings > 1
              ? () => setState(() => _servings -= 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        SizedBox(
          width: 32,
          child: Text(
            _servings == _servings.roundToDouble()
                ? '${_servings.round()}'
                : _servings.toStringAsFixed(1),
            key: const Key('servings_value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
        ),
        IconButton(
          key: const Key('servings_plus'),
          tooltip: 'More servings',
          onPressed: _servings < Recipe.maxServings
              ? () => setState(() => _servings += 1)
              : null,
          icon: Icon(Icons.add_circle_rounded, color: context.appPrimary),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }

  Widget _nutritionCard(BuildContext context) {
    final n = _r.perServing;
    Widget cell(String label, double? v, {bool big = false}) => Expanded(
      child: Column(
        children: [
          Text(
            recipeNumber(v, partial: n.partial),
            style: TextStyle(
              fontSize: big ? 24 : 19,
              fontWeight: FontWeight.w900,
              color: v == null
                  ? context.appTextMuted
                  : (big ? context.appPrimary : context.appTextPrimary),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: context.appTextSecondary),
          ),
        ],
      ),
    );
    final sources = {for (final i in _r.ingredients) i.toItem().sourceLabel};
    return GlassPanel(
      key: const Key('nutrition_card'),
      borderColor: context.appPrimary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PER SERVING',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell('kcal', n.calories, big: true),
              cell('protein g', n.protein),
              cell('carbs g', n.carbs),
              cell('fat g', n.fat),
            ],
          ),
          const SizedBox(height: 8),
          if (n.partial)
            Text(
              '+ means some ingredients have no value for that nutrient and are '
              'not counted.',
              style: TextStyle(fontSize: 11, color: context.appTextMuted),
            ),
          Text(
            n.estimates
                ? 'Calculated from the ingredients. Includes typical or '
                      'estimated values (${sources.join(', ')}), not lab '
                      'measurements.'
                : 'Calculated from the ingredients (${sources.join(', ')}).',
            key: const Key('nutrition_source'),
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: context.appTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      t.toUpperCase(),
      style: AppTheme.labelCaps.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: context.appTextSecondary,
      ),
    ),
  );

  Widget _ingredients(BuildContext context) {
    final factor = _servings / _r.servings;
    return Column(
      children: [
        for (final i in _r.ingredients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: context.appPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    i.text(factor: factor),
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _steps(BuildContext context) {
    if (_r.steps.isEmpty) {
      return Text(
        'No method written for this meal.',
        style: TextStyle(color: context.appTextMuted),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _r.steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.appPrimary.withValues(alpha: 0.16),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: context.appPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _r.steps[i],
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviews(BuildContext context, RatingSummary summary) {
    final repo = _hub.ratings;
    final list = [...repo.ratingsFor(_r.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final own = repo.mine(_r.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!repo.available)
          Text(
            repo.unavailableReason ?? 'Ratings are not available.',
            key: const Key('ratings_unavailable'),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: context.appTextSecondary,
            ),
          )
        else ...[
          if (list.where((r) => (r.review ?? '').isNotEmpty).isEmpty)
            Text(
              summary.hasRatings
                  ? 'No written reviews yet.'
                  : 'Be the first to rate this recipe.',
              style: TextStyle(color: context.appTextSecondary),
            ),
          for (final r in list)
            if ((r.review ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileImage(path: r.raterAvatar, size: 32, iconSize: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.raterName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: context.appTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${'★' * r.stars}${'☆' * (5 - r.stars)}',
                                style: const TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.review!,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: context.appTextSecondary,
                            ),
                          ),
                          if (r.isSample)
                            Text(
                              'Sample review',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.appTextMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const Key('rate_button'),
          onPressed: _rate,
          icon: const Icon(Icons.star_outline_rounded),
          label: Text(own == null ? 'Rate this recipe' : 'Update your rating'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appPrimary,
            side: BorderSide(color: context.appPrimary),
            minimumSize: const Size(0, 46),
          ),
        ),
      ],
    );
  }

  Widget _actionBar(BuildContext context, bool saved) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appOutlineVariant)),
      ),
      child: Row(
        children: [
          IconButton.outlined(
            key: const Key('detail_save'),
            tooltip: saved ? 'Remove from saved' : 'Save recipe',
            onPressed: _toggleSave,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? context.appPrimary : context.appTextSecondary,
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('add_to_plan'),
              onPressed: _addToPlan,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appPrimary,
                side: BorderSide(color: context.appPrimary),
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Add to plan',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const Key('log_to_diary'),
              onPressed: _logToDiary,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Log to diary',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- sheets ----------------------------------------------------------------

class _RateSheet extends StatefulWidget {
  const _RateSheet({
    required this.initialStars,
    required this.initialReview,
    required this.updating,
  });

  final int initialStars;
  final String initialReview;
  final bool updating;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late int _stars = widget.initialStars;
  late final TextEditingController _review = TextEditingController(
    text: widget.initialReview,
  );
  String? _error;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.updating ? 'Update your rating' : 'Rate this recipe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One rating each. Rating again replaces yours.',
            style: TextStyle(fontSize: 12.5, color: context.appTextSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('star_$i'),
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setState(() {
                    _stars = i;
                    _error = null;
                  }),
                  icon: Icon(
                    i <= _stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFBBF24),
                    size: 34,
                  ),
                ),
            ],
          ),
          TextField(
            key: const Key('review_field'),
            controller: _review,
            maxLines: 3,
            maxLength: 600,
            decoration: const InputDecoration(
              labelText: 'Review (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFF87171))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('submit_rating'),
              onPressed: () {
                if (_stars < 1) {
                  setState(() => _error = 'Choose 1 to 5 stars.');
                  return;
                }
                Navigator.pop(context, (_stars, _review.text.trim()));
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                widget.updating ? 'Update rating' : 'Submit rating',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slot and servings picker with the resulting calories and macros.
class _PortionSheet extends StatefulWidget {
  const _PortionSheet({
    required this.recipe,
    required this.title,
    required this.confirmLabel,
    required this.initialServings,
    required this.showDays,
  });

  final Recipe recipe;
  final String title;
  final String confirmLabel;
  final double initialServings;
  final bool showDays;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late double _servings = widget.initialServings;
  late MealCategory _slot = widget.recipe.categories.isEmpty
      ? MealCategory.lunch
      : widget.recipe.categories.first.slot;

  @override
  Widget build(BuildContext context) {
    final n = widget.recipe.perServing;
    String v(double? x) => x == null ? '--' : '${(x * _servings).round()}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in MealCategory.values)
                  ChoiceChip(
                    key: Key('slot_${m.name}'),
                    label: Text(
                      m == MealCategory.snack
                          ? 'Snack'
                          : '${m.name[0].toUpperCase()}${m.name.substring(1)}',
                    ),
                    selected: _slot == m,
                    onSelected: (_) => setState(() => _slot = m),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Servings',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('sheet_minus'),
                  onPressed: _servings > 0.5
                      ? () => setState(() => _servings -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
                Text(
                  _servings == _servings.roundToDouble()
                      ? '${_servings.round()}'
                      : _servings.toStringAsFixed(1),
                  key: const Key('sheet_servings'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
                IconButton(
                  key: const Key('sheet_plus'),
                  onPressed: _servings < 20
                      ? () => setState(() => _servings += 0.5)
                      : null,
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: context.appPrimary,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ],
            ),
            Text(
              '${v(n.calories)} kcal · P ${v(n.protein)} g · C ${v(n.carbs)} g · F ${v(n.fat)} g',
              key: const Key('sheet_nutrition'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            if (n.partial)
              Text(
                'Some ingredients have no value for every nutrient.',
                style: TextStyle(fontSize: 11, color: context.appTextMuted),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('sheet_confirm'),
                onPressed: () => Navigator.pop(context, (_slot, _servings)),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 48),
                ),
                child: Text(
                  widget.confirmLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChoice {
  final MealPrep? plan;
  final int day;
  final MealCategory slot;
  final double servings;
  const _PlanChoice(this.plan, this.day, this.slot, this.servings);
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.recipe, required this.plans});

  final Recipe recipe;
  final List<MealPrep> plans;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  MealPrep? _plan;
  int _day = 0;
  double _servings = 1;
  late MealCategory _slot = widget.recipe.categories.isEmpty
      ? MealCategory.lunch
      : widget.recipe.categories.first.slot;

  int get _days => _plan == null ? 1 : _plan!.days;

  @override
  Widget build(BuildContext context) {
    final maxDay = _days < MealPrep.maxDays ? _days : MealPrep.maxDays - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to a meal plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  key: const Key('plan_new'),
                  label: const Text('New plan'),
                  selected: _plan == null,
                  onSelected: (_) => setState(() {
                    _plan = null;
                    _day = 0;
                  }),
                ),
                for (final p in widget.plans)
                  ChoiceChip(
                    key: Key('plan_${p.id}'),
                    label: Text(p.name, overflow: TextOverflow.ellipsis),
                    selected: _plan?.id == p.id,
                    onSelected: (_) => setState(() {
                      _plan = p;
                      _day = 0;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var d = 0; d <= maxDay && d < MealPrep.maxDays; d++)
                  ChoiceChip(
                    key: Key('plan_day_$d'),
                    label: Text('Day ${d + 1}${d >= _days ? ' (new)' : ''}'),
                    selected: _day == d,
                    onSelected: (_) => setState(() => _day = d),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in MealCategory.values)
                  ChoiceChip(
                    key: Key('plan_slot_${m.name}'),
                    label: Text(
                      m == MealCategory.snack
                          ? 'Snack'
                          : '${m.name[0].toUpperCase()}${m.name.substring(1)}',
                    ),
                    selected: _slot == m,
                    onSelected: (_) => setState(() => _slot = m),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Servings',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _servings > 0.5
                      ? () => setState(() => _servings -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
                Text(
                  _servings == _servings.roundToDouble()
                      ? '${_servings.round()}'
                      : _servings.toStringAsFixed(1),
                  key: const Key('plan_servings'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
                IconButton(
                  onPressed: _servings < 20
                      ? () => setState(() => _servings += 0.5)
                      : null,
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: context.appPrimary,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('plan_confirm'),
                onPressed: () => Navigator.pop(
                  context,
                  _PlanChoice(_plan, _day, _slot, _servings),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPrimary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text(
                  'Add to plan',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
