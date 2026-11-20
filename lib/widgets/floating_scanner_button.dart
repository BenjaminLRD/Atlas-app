import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/unified_food_scanner_screen.dart';

/// Small, translucent floating action button displayed above the AI Coach chat bubble.
/// Triggers the unified food recognition and barcode scanner without creating redundant routes.
class FloatingScannerButton extends StatefulWidget {
  final double size;
  final VoidCallback? onCustomTap;

  const FloatingScannerButton({
    super.key,
    this.size = 40.0,
    this.onCustomTap,
  });

  @override
  State<FloatingScannerButton> createState() => _FloatingScannerButtonState();
}

class _FloatingScannerButtonState extends State<FloatingScannerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isOpening) return;
    _isOpening = true;

    if (widget.onCustomTap != null) {
      widget.onCustomTap!();
      _isOpening = false;
      return;
    }

    try {
      await UnifiedFoodScannerScreen.show(context);
    } finally {
      if (mounted) {
        _isOpening = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'Open Food and Barcode Scanner',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) {
            _pressController.reverse();
            _handleTap();
          },
          onTapCancel: () => _pressController.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isHovered
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.32)
                            : Colors.black.withValues(alpha: 0.35))
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.24)
                            : Colors.black.withValues(alpha: 0.28)),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: _isHovered ? 0.40 : 0.20,
                      ),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
