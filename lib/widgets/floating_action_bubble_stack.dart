import 'package:flutter/material.dart';
import 'ai_chat_button.dart';
import 'floating_scanner_button.dart';

/// Floating action group rendering the small translucent scanner button stacked
/// vertically directly above the primary AI Coach chat bubble with 8dp spacing.
class FloatingActionBubbleStack extends StatefulWidget {
  final VoidCallback? onScannerTap;
  final VoidCallback? onChatTap;

  const FloatingActionBubbleStack({
    super.key,
    this.onScannerTap,
    this.onChatTap,
  });

  @override
  State<FloatingActionBubbleStack> createState() =>
      _FloatingActionBubbleStackState();
}

class _FloatingActionBubbleStackState extends State<FloatingActionBubbleStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Small Floating Scanner Button (~40x40)
            FloatingScannerButton(
              size: 40.0,
              onCustomTap: widget.onScannerTap,
            ),
            const SizedBox(height: 8.0),
            // 2. Main AI Coach Chat Bubble (~52x52)
            const AiChatButton(),
          ],
        ),
      ),
    );
  }
}
