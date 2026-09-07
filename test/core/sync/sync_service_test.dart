import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:social_feed_app/core/database/app_database.dart';
import 'package:social_feed_app/core/database/pending_write.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/network_info/connectivity_store.dart';
import 'package:social_feed_app/core/sync/sync_service.dart';

/// Stand-in for the real platform plugin so [AppDatabase] can resolve an
/// application documents directory on the Dart VM. Points at a fresh temp
/// directory per test run instead of any real device path.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directoryPath);

  final String directoryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => directoryPath;
}

class _MockConnectivity extends Mock implements Connectivity {}

Future<void> _insertPendingWrite(
  AppDatabase appDatabase,
  PendingWrite write,
) async {
  final db = await appDatabase.database;
  await db.insert(AppDatabase.pendingWritesTable, write.toRow());
}

Future<List<PendingWrite>> _readPendingWrites(AppDatabase appDatabase) async {
  final db = await appDatabase.database;
  final rows = await db.query(
    AppDatabase.pendingWritesTable,
    orderBy: 'created_at ASC',
  );
  return rows.map(PendingWrite.fromRow).toList();
}

void main() {
  late Directory tempDirectory;
  late AppDatabase appDatabase;
  late ConnectivityStore connectivityStore;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDirectory = Directory.systemTemp.createTempSync('sync_service_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    appDatabase = AppDatabase();

    final mockConnectivity = _MockConnectivity();
    when(
      () => mockConnectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(
      () => mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => const Stream.empty());

    connectivityStore = ConnectivityStore(connectivity: mockConnectivity);
    // Let the store's own async initial check settle before the test takes
    // over driving `isOnline` by hand, so it does not race a manual set.
    await pumpEventQueue();
  });

  tearDown(() async {
    connectivityStore.dispose();
    await appDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  PendingWrite writeAt(int minutesAgo, {String entityType = 'post'}) {
    return PendingWrite(
      entityType: entityType,
      payloadJson: '{"title":"$entityType-$minutesAgo"}',
      operation: PendingWriteOperation.create,
      createdAt: DateTime(2026, 1, 1).add(Duration(minutes: minutesAgo)),
    );
  }

  group('SyncService offline-to-online replay', () {
    test('replays a queued write once isOnline flips from false to true and removes it on success', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      final replayed = <PendingWrite>[];
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayed.add(write);
          return const Right(null);
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      // The reaction fires synchronously and kicks off the same in-flight
      // drain this awaits, so this reliably waits for it to finish instead
      // of guessing how many event loop turns the sqflite ffi isolate
      // round trip needs.
      await syncService.syncNow();

      expect(replayed, hasLength(1));
      final remaining = await _readPendingWrites(appDatabase);
      expect(remaining, isEmpty);

      syncService.dispose();
    });

    test('replays queued writes oldest first', () async {
      await _insertPendingWrite(appDatabase, writeAt(5, entityType: 'newer'));
      await _insertPendingWrite(appDatabase, writeAt(1, entityType: 'older'));

      final replayedEntityTypes = <String>[];
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayedEntityTypes.add(write.entityType);
          return const Right(null);
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      await syncService.syncNow();

      expect(replayedEntityTypes, ['older', 'newer']);

      syncService.dispose();
    });

    test('does not replay anything when isOnline stays true', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      var replayCount = 0;
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayCount++;
          return const Right(null);
        },
      );
      syncService.start();

      // Already online from setUp; toggling it to the same value should
      // not be treated as a reconnect.
      connectivityStore.isOnline = true;
      await pumpEventQueue();

      expect(replayCount, 0);
      final remaining = await _readPendingWrites(appDatabase);
      expect(remaining, hasLength(1));

      syncService.dispose();
    });
  });

  group('SyncService failed replay', () {
    test('leaves a failed write queued, and retries it on the next syncNow call', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      var replayCount = 0;
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayCount++;
          return const Left(NetworkFailure('still offline'));
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      await syncService.syncNow();

      expect(replayCount, 1);
      var remaining = await _readPendingWrites(appDatabase);
      expect(remaining, hasLength(1));

      await syncService.syncNow();

      expect(replayCount, 2);
      remaining = await _readPendingWrites(appDatabase);
      expect(remaining, hasLength(1));
      expect(remaining.single.entityType, 'post');

      syncService.dispose();
    });

    test('a write that starts failing and later succeeds is removed once it does', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      var attempt = 0;
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          attempt++;
          if (attempt == 1) {
            return const Left(NetworkFailure('still offline'));
          }
          return const Right(null);
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      await syncService.syncNow();
      expect(await _readPendingWrites(appDatabase), hasLength(1));

      await syncService.syncNow();

      expect(attempt, 2);
      expect(await _readPendingWrites(appDatabase), isEmpty);

      syncService.dispose();
    });
  });

  group('SyncService replayer throws', () {
    test('leaves a write queued when the replayer throws instead of returning Left', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          throw StateError('boom');
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      await syncService.syncNow();

      final remaining = await _readPendingWrites(appDatabase);
      expect(remaining, hasLength(1));

      syncService.dispose();
    });

    test('continues draining the rest of the batch after one replay throws', () async {
      await _insertPendingWrite(appDatabase, writeAt(1, entityType: 'throws'));
      await _insertPendingWrite(appDatabase, writeAt(5, entityType: 'succeeds'));

      final replayedEntityTypes = <String>[];
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayedEntityTypes.add(write.entityType);
          if (write.entityType == 'throws') {
            throw StateError('boom');
          }
          return const Right(null);
        },
      );
      syncService.start();

      connectivityStore.isOnline = false;
      connectivityStore.isOnline = true;
      await syncService.syncNow();

      expect(replayedEntityTypes, ['throws', 'succeeds']);
      final remaining = await _readPendingWrites(appDatabase);
      expect(remaining, hasLength(1));
      expect(remaining.single.entityType, 'throws');

      syncService.dispose();
    });
  });

  group('SyncService.syncNow in-flight de-duplication', () {
    test('concurrent syncNow calls share a single drain rather than racing', () async {
      await _insertPendingWrite(appDatabase, writeAt(1));

      var replayCount = 0;
      final syncService = SyncService(
        appDatabase: appDatabase,
        connectivityStore: connectivityStore,
        replayer: (write) async {
          replayCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Right(null);
        },
      );

      final firstCall = syncService.syncNow();
      final secondCall = syncService.syncNow();
      await Future.wait([firstCall, secondCall]);

      expect(replayCount, 1);
      expect(await _readPendingWrites(appDatabase), isEmpty);
    });
  });
}
