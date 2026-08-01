import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../screens/ai_coach_chat_screen.dart';

class AiChatButton extends StatefulWidget {
  const AiChatButton({super.key});

  @override
  State<AiChatButton> createState() => _AiChatButtonState();
}

class _AiChatButtonState extends State<AiChatButton> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseGlowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseGlowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (!tickerEnabled || disableAnimations) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          _navigateToChat();
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double glowRadius = _isHovered ? 18.0 : _pulseGlowAnimation.value;
              final double breathScale = 1.0 + (_pulseController.value * 0.04);

              return Transform.scale(
                scale: breathScale,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF165B22), Color(0xFF0F3818)]
                          : const [AppColors.primaryContainer, AppColors.primary],
                    ),
                    border: Border.all(
                      color: AppColors.primaryContainer,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.65 : 0.45),
                        blurRadius: glowRadius * 1.5,
                        spreadRadius: _isHovered ? 3 : 1.5,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.25),
                        blurRadius: glowRadius * 0.7,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AiCoachChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
