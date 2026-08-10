import 'package:flutter/material.dart';
import '../widgets/common/wearable_connection_card.dart';

/// Full screen interface for managing connected wearable health devices.
class WearableDevicesScreen extends StatelessWidget {
  const WearableDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: const Text(
          'Wearable Integrations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Health Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your Apple Watch, Pixel Watch, Fitbit, or Garmin device to automatically feed daily steps, sleep, resting heart rate, and HRV metrics into your AI Recovery & Readiness engine.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            const WearableConnectionCard(),
          ],
        ),
      ),
    );
  }
}
