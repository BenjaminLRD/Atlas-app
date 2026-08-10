import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sync_metadata.dart';
import '../providers/fitness_provider.dart';

/// Reactive indicator widget displaying the current sync state:
/// - Synced (Synced ✓)
/// - Syncing (Syncing...)
/// - Offline (Offline)
/// - Error (Error)
class SyncStatusIndicator extends StatelessWidget {
  final SyncMetadata? metadata;
  final VoidCallback? onTap;
  final bool compact;

  const SyncStatusIndicator({
    super.key,
    this.metadata,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (metadata != null) {
      return _buildContent(context, metadata!);
    }

    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final activeMetadata = FitnessProvider.instance.syncMetadata;
        return _buildContent(context, activeMetadata);
      },
    );
  }

  Widget _buildContent(BuildContext context, SyncMetadata meta) {
    final status = meta.syncStatus;
    Color statusColor;
    IconData iconData;
    String labelText;

    switch (status) {
      case SyncStatus.synced:
        statusColor = const Color(0xFF10B981); // Vibrant Emerald Green
        iconData = Icons.check_circle;
        labelText = compact ? 'Synced' : 'Synced ✓';
        break;
      case SyncStatus.syncing:
        statusColor = const Color(0xFF3B82F6); // Electric Blue
        iconData = Icons.sync;
        labelText = 'Syncing...';
        break;
      case SyncStatus.offline:
        statusColor = const Color(0xFFF59E0B); // Amber / Orange
        iconData = Icons.cloud_off;
        labelText = 'Offline';
        break;
      case SyncStatus.error:
        statusColor = const Color(0xFFEF4444); // Crimson Red
        iconData = Icons.error_outline;
        labelText = 'Error';
        break;
    }

    return GestureDetector(
      onTap: onTap ?? () => FitnessProvider.instance.syncData(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == SyncStatus.syncing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              )
            else
              Icon(
                iconData,
                size: 14,
                color: statusColor,
              ),
            const SizedBox(width: 6),
            Text(
              labelText,
              style: GoogleFonts.hankenGrotesk(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
