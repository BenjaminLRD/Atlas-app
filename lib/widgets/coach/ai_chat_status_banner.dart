import 'package:flutter/material.dart';

/// Thin status strip under the AI chat header.
///
/// It states only what is known locally: whether Atlas AI can be used right
/// now (signed in and the AI backend configured). It does not claim anything
/// about learning, data sources or connectivity.
class AiChatStatusBanner extends StatelessWidget {
  final bool isSignedIn;

  /// True when this build has no AI backend, so signing in would not help.
  final bool backendMissing;

  /// True in Showcase Mode, where Atlas AI needs no account.
  final bool isShowcase;

  const AiChatStatusBanner({
    super.key,
    required this.isSignedIn,
    this.backendMissing = false,
    this.isShowcase = false,
  });

  static const String showcaseText = 'Showcase Mode: no sign-in needed';

  static const String signedInText = 'Signed in';
  static const String signedOutText = 'Sign in to chat with Atlas AI';
  static const String backendMissingText = 'AI is not set up in this build';

  @override
  Widget build(BuildContext context) {
    final dotColor = isSignedIn || (isShowcase && !backendMissing)
        ? const Color(0xFF10B981)
        : Colors.white38;
    return Container(
      key: const Key('ai_status_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF14151B),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text(
            'Atlas AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              backendMissing
                  ? backendMissingText
                  : isShowcase
                  ? showcaseText
                  : (isSignedIn ? signedInText : signedOutText),
              key: const Key('ai_status_text'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
