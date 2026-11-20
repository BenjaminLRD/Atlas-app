import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/motivational_quote.dart';
import 'app_button.dart';
import 'app_image.dart';

/// Interactive modal sheet displaying Quote of the Day with verified character artwork or branded visual placeholder.
class MotivationalQuoteBottomSheet extends StatefulWidget {
  final List<MotivationalQuote>? quotes;
  final int initialIndex;

  const MotivationalQuoteBottomSheet({
    super.key,
    this.quotes,
    this.initialIndex = 0,
  });

  @override
  State<MotivationalQuoteBottomSheet> createState() =>
      _MotivationalQuoteBottomSheetState();
}

class _MotivationalQuoteBottomSheetState
    extends State<MotivationalQuoteBottomSheet>
    with SingleTickerProviderStateMixin {
  late final List<MotivationalQuote> _quotes;
  late int _currentIndex;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _quotes = widget.quotes ?? MotivationalQuote.defaultCatalog();
    _currentIndex = _quotes.isNotEmpty
        ? (widget.initialIndex % _quotes.length)
        : 0;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextQuote() {
    if (_quotes.isEmpty) return;
    _animController.forward(from: 0.0);
    setState(() {
      _currentIndex = (_currentIndex + 1) % _quotes.length;
    });
  }

  void _shareQuote(MotivationalQuote quote) {
    final textToShare =
        '"${quote.quoteText}" — ${quote.characterName} (${quote.characterSource})';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quote copied to clipboard:\n$textToShare',
          style: AppTheme.bodySm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final quote = _quotes[_currentIndex];
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomInset + 12,
        top: 24,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121815) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(
              alpha: isDark ? 0.2 : 0.1,
            ),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header Bar: QUOTE OF THE DAY & Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primaryContainer,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QUOTE OF THE DAY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.primaryContainer
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.appSurfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.appOutlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: context.appTextSecondary,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Animated Quote Content Row/Column
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;
                    final characterCard = _buildCharacterArtworkCard(
                      context,
                      quote,
                    );
                    final quoteDetailCard = _buildQuoteDetailCard(
                      context,
                      quote,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 210,
                            height: 230,
                            child: characterCard,
                          ),
                          const SizedBox(width: 18),
                          Expanded(child: quoteDetailCard),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 185, child: characterCard),
                          const SizedBox(height: 14),
                          quoteDetailCard,
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Action Buttons: Another Quote & Share
            LayoutBuilder(
              builder: (context, buttonConstraints) {
                final useVertical = buttonConstraints.maxWidth < 270;
                if (useVertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton.primary(
                        label: 'Another Quote',
                        icon: Icons.autorenew_rounded,
                        onPressed: _nextQuote,
                      ),
                      const SizedBox(height: 10),
                      AppButton.secondary(
                        label: 'Share',
                        icon: Icons.ios_share_rounded,
                        onPressed: () => _shareQuote(quote),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        label: 'Another Quote',
                        icon: Icons.autorenew_rounded,
                        onPressed: _nextQuote,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Share',
                        icon: Icons.ios_share_rounded,
                        onPressed: () => _shareQuote(quote),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterArtworkCard(
    BuildContext context,
    MotivationalQuote quote,
  ) {
    final isDark = context.isDarkMode;

    if (quote.hasDedicatedAsset) {
      return Container(
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.primaryContainer.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(
                alpha: isDark ? 0.25 : 0.12,
              ),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AppImage.quote(
            imageUrl: quote.imageUrl,
            assetPath: quote.assetPath,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 18,
            characterName: quote.characterName,
          ),
        ),
      );
    }

    return _buildDedicatedQuotePlaceholder(context, quote);
  }

  /// Premium, intentional Quote of the Day placeholder widget matching Atlas design system.
  Widget _buildDedicatedQuotePlaceholder(
    BuildContext context,
    MotivationalQuote quote,
  ) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0F1E15), Color(0xFF183324)]
              : [
                  AppColors.primaryContainer.withValues(alpha: 0.18),
                  AppColors.primaryContainer.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.primaryContainer.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(
              alpha: isDark ? 0.25 : 0.12,
            ),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative watermark quote mark
          Positioned(
            right: 8,
            bottom: -6,
            child: Text(
              '“',
              style: TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.w900,
                fontFamily: 'serif',
                color: AppColors.primaryContainer.withValues(
                  alpha: isDark ? 0.08 : 0.06,
                ),
                height: 1.0,
              ),
            ),
          ),

          // Central badge & attribution
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Avatar Circle with Character Symbol
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    quote.avatarSymbol,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Character Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    quote.characterName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: isDark
                          ? AppColors.primaryContainer
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Power Tag Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    quote.powerTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.onSurface : AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteDetailCard(BuildContext context, MotivationalQuote quote) {
    final quoteText = quote.quoteText;
    final highlightText = quote.highlightText;
    final parts = quoteText.split(highlightText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Green quote symbol badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '“',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryContainer,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quote Rich Text with Vitality Green Highlight
        RichText(
          text: TextSpan(
            style: AppTheme.headlineMd.copyWith(
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
            children: [
              const TextSpan(text: '“ '),
              if (parts.isNotEmpty) TextSpan(text: parts.first),
              TextSpan(
                text: highlightText,
                style: TextStyle(
                  color: context.isDarkMode
                      ? AppColors.primaryContainer
                      : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (parts.length > 1) TextSpan(text: parts.last),
              const TextSpan(text: ' ”'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Character Attribution
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 2,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                quote.characterName,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.isDarkMode
                      ? AppColors.primaryContainer
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '•  ${quote.characterSource}',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
