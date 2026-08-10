import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/daily_motivation_service.dart';
import 'app_animation.dart';
import 'app_card.dart';

/// Glassmorphic Daily Motivation Card component for Dashboard screen.
class DailyMotivationCard extends StatefulWidget {
  final String? categoryPreference;
  final VoidCallback? onShare;

  const DailyMotivationCard({
    super.key,
    this.categoryPreference,
    this.onShare,
  });

  @override
  State<DailyMotivationCard> createState() => _DailyMotivationCardState();
}

class _DailyMotivationCardState extends State<DailyMotivationCard>
    with SingleTickerProviderStateMixin {
  late DailyMotivationQuote _currentQuote;
  late final AnimationController _rotationController;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _currentQuote = DailyMotivationService.getDailyQuote(category: widget.categoryPreference);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _refreshQuote() {
    _rotationController.forward(from: 0.0);
    setState(() {
      _currentQuote = DailyMotivationService.getRandomQuote(category: widget.categoryPreference);
      _isLiked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AppAnimation.slideFadeIn(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY MOTIVATION',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * 3.14159,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: context.appTextSecondary,
                            ),
                          );
                        },
                      ),
                      onPressed: _refreshQuote,
                      tooltip: 'New quote',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: _isLiked ? Colors.redAccent : context.appTextSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isLiked = !_isLiked;
                        });
                      },
                      tooltip: 'Like quote',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. Quote Text
            AnimatedSwitcher(
              duration: AppDurations.medium,
              child: Text(
                '"${_currentQuote.quote}"',
                key: ValueKey(_currentQuote.id),
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: context.appTextPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 3. Author Attribution
            Text(
              '— ${_currentQuote.author}',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Coach Action Tip Pill
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: AppRadii.borderMd,
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 16,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentQuote.coachTip,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
