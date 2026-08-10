import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/models/sync_metadata.dart';
import 'package:aizawl_gym/services/sync/mock_sync_provider.dart';
import 'package:aizawl_gym/services/sync/sync_queue.dart';
import 'package:aizawl_gym/services/sync/sync_service.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/widgets/sync_status_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FitnessProvider.resetInstance();
  });

  group('SyncProvider & MockSyncProvider Unit Tests', () {
    test('upload and download store and retrieve data correctly', () async {
      final provider = MockSyncProvider();
      await provider.upload({'name': 'John'}, 'user_key');

      final downloaded =
          await provider.download<Map<String, dynamic>>('user_key');
      expect(downloaded, isNotNull);
      expect(downloaded!['name'], equals('John'));
    });

    test('upload throws SyncException when device is offline', () async {
      final provider = MockSyncProvider();
      provider.setOnline(false);

      expect(
        () => provider.upload('data', 'key1'),
        throwsA(isA<SyncException>()),
      );
    });

    test('upload throws SyncException on simulated upload failure', () async {
      final provider = MockSyncProvider();
      provider.setShouldFailUpload(true);

      expect(
        () => provider.upload('data', 'key1'),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('SyncQueue Operations Unit Tests', () {
    test('addOperation, removeOperation, and getPendingOperations work', () {
      final queue = SyncQueue();
      final op1 = SyncOperation(
          operationId: '1', type: 'upload', key: 'k1', payload: 'p1');
      final op2 = SyncOperation(
          operationId: '2', type: 'upload', key: 'k2', payload: 'p2');

      queue.addOperation(op1);
      queue.addOperation(op2);

      expect(queue.length, equals(2));
      expect(queue.getPendingOperations().length, equals(2));

      final removed = queue.removeOperation('1');
      expect(removed, isTrue);
      expect(queue.length, equals(1));
      expect(queue.getPendingOperations().first.key, equals('k2'));
    });
  });

  group('SyncService & Conflict Resolution Tests', () {
    test('timestamp-based conflict resolution chooses newer payload', () {
      final service = SyncService();
      final olderTime = DateTime(2026, 1, 1);
      final newerTime = DateTime(2026, 1, 2);

      final winnerRemote = service.resolveConflict(
        localPayload: 'local_old',
        localTimestamp: olderTime,
        remotePayload: 'remote_new',
        remoteTimestamp: newerTime,
      );
      expect(winnerRemote, equals('remote_new'));

      final winnerLocal = service.resolveConflict(
        localPayload: 'local_new',
        localTimestamp: newerTime,
        remotePayload: 'remote_old',
        remoteTimestamp: olderTime,
      );
      expect(winnerLocal, equals('local_new'));
    });

    test(
        'synchronize processes queue, updates lastSyncTime, and sets synced status',
        () async {
      final mockProvider = MockSyncProvider();
      final service = SyncService(provider: mockProvider);

      service.recordLocalChange(key: 'profile', payload: {'name': 'Alice'});
      expect(service.pendingChangesCount, equals(1));

      final meta = await service.synchronize();
      expect(meta.syncStatus, equals(SyncStatus.synced));
      expect(meta.lastSyncTime, isNotNull);
      expect(service.pendingChangesCount, equals(0));
      expect(mockProvider.cloudStorage['profile'], equals({'name': 'Alice'}));
    });

    test('synchronize sets offline status on network disconnect', () async {
      final mockProvider = MockSyncProvider();
      mockProvider.setOnline(false);
      final service = SyncService(provider: mockProvider);

      await expectLater(
        service.synchronize(),
        throwsA(isA<SyncException>()),
      );
      expect(service.metadata.syncStatus, equals(SyncStatus.offline));
    });
  });

  group('FitnessProvider Integration Tests', () {
    test('syncData triggers sync, updates metadata, and notifies listeners',
        () async {
      final mockProvider = MockSyncProvider();
      final syncService = SyncService(provider: mockProvider);
      final fitnessProvider = FitnessProvider(syncService: syncService);

      int notifyCount = 0;
      fitnessProvider.addListener(() {
        notifyCount++;
      });

      expect(
          fitnessProvider.syncMetadata.syncStatus, equals(SyncStatus.synced));

      await fitnessProvider.syncData();

      expect(notifyCount, greaterThanOrEqualTo(2));
      expect(
          fitnessProvider.syncMetadata.syncStatus, equals(SyncStatus.synced));
      expect(fitnessProvider.syncMetadata.lastSyncTime, isNotNull);
    });
  });

  group('SyncStatusIndicator UI Widget Tests', () {
    testWidgets('renders Synced state correctly', (WidgetTester tester) async {
      const meta = SyncMetadata(
        syncStatus: SyncStatus.synced,
        deviceId: 'dev_1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(metadata: meta),
          ),
        ),
      );

      expect(find.text('Synced ✓'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders Syncing state correctly', (WidgetTester tester) async {
      const meta = SyncMetadata(
        syncStatus: SyncStatus.syncing,
        deviceId: 'dev_1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(metadata: meta),
          ),
        ),
      );

      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders Offline state correctly', (WidgetTester tester) async {
      const meta = SyncMetadata(
        syncStatus: SyncStatus.offline,
        deviceId: 'dev_1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(metadata: meta),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('renders Error state correctly', (WidgetTester tester) async {
      const meta = SyncMetadata(
        syncStatus: SyncStatus.error,
        deviceId: 'dev_1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncStatusIndicator(metadata: meta),
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
