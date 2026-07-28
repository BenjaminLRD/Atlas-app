import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../screens/ai_coach_chat_screen.dart';

class AiChatButton extends StatefulWidget {
  const AiChatButton({super.key});

  @override
  State<AiChatButton> createState() => _AiChatButtonState();
}

class _AiChatButtonState extends State<AiChatButton> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseGlowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Animation for tapping interaction (press down shrink)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Animation for continuous idle breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    _pulseGlowAnimation = Tween<double>(begin: 4.0, end: 14.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          _navigateToChat();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double currentPulseScale = _isHovered ? 1.0 : _pulseScaleAnimation.value;
              final double currentGlowRadius = _isHovered ? 20.0 : _pulseGlowAnimation.value;

              return Transform.scale(
                scale: currentPulseScale,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Dual shadow layers for modern neon glow effect
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: _isHovered ? 0.45 : 0.25),
                        blurRadius: currentGlowRadius,
                        spreadRadius: _isHovered ? 4 : 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: currentGlowRadius * 1.5,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          // Sleek semi-transparent glass container with primary green accent tint
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: _isHovered ? 0.9 : 0.65),
                              AppColors.primary.withValues(alpha: _isHovered ? 0.8 : 0.5),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.onPrimary.withValues(alpha: _isHovered ? 0.4 : 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: AnimatedRotation(
                            turns: _isHovered ? 0.05 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.onPrimary.withValues(alpha: _isHovered ? 1.0 : 0.95),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
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
