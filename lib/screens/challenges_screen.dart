import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/community/challenges_tab.dart';

/// The Challenges tab as its own page, for links from other screens.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChallengesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Challenges',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: const SafeArea(child: ChallengesTab()),
    );
  }
}
