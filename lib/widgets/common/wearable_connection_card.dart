import 'package:flutter/material.dart';
import '../../models/connected_device.dart';
import '../../providers/fitness_provider.dart';

/// Interactive UI Card displaying paired wearable health devices, sync status, and platform controls.
class WearableConnectionCard extends StatefulWidget {
  const WearableConnectionCard({super.key});

  @override
  State<WearableConnectionCard> createState() => _WearableConnectionCardState();
}

class _WearableConnectionCardState extends State<WearableConnectionCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final devices = provider.connectedDevices;
    final healthMetrics = provider.healthMetrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.watch_rounded,
                      color: Color(0xFF6C5CE7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wearable Health Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        healthMetrics != null
                            ? 'Source: ${healthMetrics.sourceDevice}'
                            : 'No active device connected',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: _isSyncing
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isSyncing = true);
                        await provider.syncHealthData();
                        if (!mounted) return;
                        setState(() => _isSyncing = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Wearable health metrics synchronized!'),
                            backgroundColor: Color(0xFF00B894),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C5CE7),
                        ),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        color: Colors.white70,
                      ),
                tooltip: 'Sync metrics now',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          // Render Wearable Devices List
          ...devices.map((device) => _buildDeviceRow(context, provider, device)),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context,
    FitnessProvider provider,
    ConnectedDevice device,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                device.isConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                color: device.isConnected
                    ? const Color(0xFF00B894)
                    : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      color: device.isConnected ? Colors.white : Colors.white60,
                      fontSize: 14,
                      fontWeight: device.isConnected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (device.isConnected && device.lastSynced != null)
                    Text(
                      'Synced ${device.lastSynced!.hour.toString().padLeft(2, '0')}:${device.lastSynced!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: device.isConnected,
            activeTrackColor: const Color(0xFF6C5CE7),
            onChanged: (connected) async {
              if (connected) {
                await provider.connectWearableDevice(device);
              } else {
                await provider.disconnectWearableDevice(device.id);
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
