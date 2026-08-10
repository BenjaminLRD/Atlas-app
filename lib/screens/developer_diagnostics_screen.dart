import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/billing/production_billing_config.dart';
import '../services/crash/crash_reporting_service.dart';
import '../services/error/app_error_handler.dart';
import '../services/offline/offline_action_queue.dart';
import '../services/performance/performance_monitor.dart';
import '../utils/security_auditor.dart';

/// Developer and System Administrator diagnostics console for monitoring app health and readiness.
class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({super.key});

  @override
  State<DeveloperDiagnosticsScreen> createState() => _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  late AppConfig _config;
  late SecurityReport _securityReport;

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
    _securityReport = SecurityAuditor.runAudit(config: _config);
    OfflineActionQueue.instance.init();
  }

  void _refreshAudit() {
    setState(() {
      _securityReport = SecurityAuditor.runAudit(config: _config);
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorHandler = AppErrorHandler.instance;
    final crashService = CrashReportingService.instance;
    final offlineQueue = OfflineActionQueue.instance;
    final perfMonitor = PerformanceMonitor.instance;
    final isBillingReady = ProductionBillingConfig.isProductionReady();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: const Text(
          'System Diagnostics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C5CE7)),
            onPressed: _refreshAudit,
            tooltip: 'Re-run Security Audit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Environment & Config Card
            _buildSectionHeader('App Environment & Config', Icons.tune_rounded),
            const SizedBox(height: 8),
            _buildConfigCard(_config),

            const SizedBox(height: 20),

            // 2. Security Audit Status
            _buildSectionHeader('Security Audit Report', Icons.security_rounded),
            const SizedBox(height: 8),
            _buildSecurityCard(_securityReport),

            const SizedBox(height: 20),

            // 3. Central Error & Crash Log Status
            _buildSectionHeader('Error & Crash Logs', Icons.bug_report_rounded),
            const SizedBox(height: 8),
            _buildErrorCrashCard(errorHandler, crashService),

            const SizedBox(height: 20),

            // 4. Offline Action Queue Status
            _buildSectionHeader('Offline Sync Queue', Icons.cloud_off_rounded),
            const SizedBox(height: 8),
            _buildOfflineQueueCard(offlineQueue),

            const SizedBox(height: 20),

            // 5. Performance Latencies
            _buildSectionHeader('Performance Latencies', Icons.speed_rounded),
            const SizedBox(height: 8),
            _buildPerformanceCard(perfMonitor),

            const SizedBox(height: 20),

            // 6. Billing Production Readiness
            _buildSectionHeader('Store Billing Readiness', Icons.shopping_bag_rounded),
            const SizedBox(height: 8),
            _buildBillingCard(isBillingReady),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(AppConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildInfoRow('Active Environment', config.environment.name.toUpperCase(), const Color(0xFF00B894)),
          _buildInfoRow('API Endpoint', config.apiBaseUrl, Colors.white70),
          _buildInfoRow('Supabase Host', config.supabaseUrl, Colors.white70),
          _buildInfoRow('Analytics Tracking', config.enableAnalytics ? 'ENABLED' : 'DISABLED', Colors.white54),
          _buildInfoRow('Crash Reporting', config.enableCrashReporting ? 'ENABLED' : 'DISABLED', Colors.white54),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(SecurityReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: report.isSecure ? const Color(0xFF00B894) : const Color(0xFFFF7675),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                report.isSecure ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: report.isSecure ? const Color(0xFF00B894) : const Color(0xFFFF7675),
              ),
              const SizedBox(width: 10),
              Text(
                report.isSecure ? 'Security Posture: PASS' : 'Security Posture: WARNING',
                style: TextStyle(
                  color: report.isSecure ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...report.passedChecks.map((check) => Text('✅ $check', style: const TextStyle(color: Colors.white70, fontSize: 12))),
          ...report.warnings.map((warn) => Text('⚠️ $warn', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12))),
          ...report.violations.map((v) => Text('❌ $v', style: const TextStyle(color: Color(0xFFFF7675), fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildErrorCrashCard(AppErrorHandler errorHandler, CrashReportingService crashService) {
    final errorsCount = errorHandler.errorHistory.length;
    final crashesCount = crashService.crashLogQueue.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Handled Errors: $errorsCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Crash Logs: $crashesCount', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              errorHandler.clearHistory();
              crashService.clearCrashLogs();
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2B55),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineQueueCard(OfflineActionQueue offlineQueue) {
    final pendingCount = offlineQueue.pendingActions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pending Actions in Queue: $pendingCount',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final processed = await offlineQueue.processQueue((action) async => true);
              if (!mounted) return;
              setState(() {});
              messenger.showSnackBar(
                SnackBar(content: Text('Flushed $processed offline actions.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            child: const Text('Flush Queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(PerformanceMonitor perfMonitor) {
    final latencies = perfMonitor.averageLatencies;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: latencies.isEmpty
          ? const Text('No performance metrics recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 13))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: latencies.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${e.value.toStringAsFixed(1)} ms', style: const TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBillingCard(bool isReady) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isReady ? const Color(0xFF00B894) : const Color(0xFFFF7675),
          ),
          const SizedBox(width: 12),
          Text(
            isReady ? 'In-App Purchase SKUs Validated' : 'Store Configuration Warning',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
