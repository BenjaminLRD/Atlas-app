import 'package:flutter/material.dart';

/// Reusable progress loading indicator with custom messages and dark glass aesthetics.
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color color;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 36.0,
    this.color = const Color(0xFF6C5CE7),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
