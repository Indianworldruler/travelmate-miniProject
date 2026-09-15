import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_service.dart';
import 'models.dart';
import 'storage_service.dart';

/// Coordinates SQLite-first writes with Firebase Realtime Database.
///
/// Local data is saved first. Every change is placed into the sync queue and
/// uploaded when Firebase reports an active connection.
///
/// Remote reads use the same local-first approach:
/// SQLite -> Firebase RTDB when necessary -> SQLite cache -> UI.
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  final StorageService _storage = StorageService.instance;
  final FirebaseService _firebase = FirebaseService.instance;

  StreamSubscription<bool>? _connectionSubscription;
  Timer? _retryTimer;

  bool _started = false;
  bool _syncing = false;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status = const SyncStatus(
    online: false,
    syncing: false,
    pendingItems: 0,
  );

  SyncStatus get status => _status;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  Future<void> start() async {
    if (_started) return;

    await _storage.initialise();

    try {
      await _firebase.initialise();

      debugPrint('TravelMate Firebase: initialized successfully.');

      _started = true;

      _connectionSubscription =
          _firebase.connectionStream.listen(_handleConnection);

      await _refreshStatus();

      // Give RTDB a moment to publish its connection state.
      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      // If a connection event already happened before the listener/status
      // settled, explicitly attempt to flush anything waiting locally.
      if (_firebase.isInitialised && _status.online) {
        await flushQueue();
      }
    } catch (error, stackTrace) {
      debugPrint('TravelMate Firebase START ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      _started = true;

      await _publishStatus(online: false);

      _scheduleRetry();
    }
  }

  Future<void> stop() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _retryTimer?.cancel();
    _retryTimer = null;

    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  Future<void> _handleConnection(bool connected) async {
    debugPrint(
      'TravelMate Firebase connection: '
      '${connected ? 'CONNECTED' : 'DISCONNECTED'}',
    );

    await _publishStatus(online: connected);

    if (connected) {
      await flushQueue();
    } else {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive == true) return;

    _retryTimer = Timer(
      const Duration(seconds: 15),
      () async {
        _retryTimer = null;

        try {
          if (!_firebase.isInitialised) {
            await _firebase.initialise();
          }

          await _refreshStatus();

          if (_status.online) {
            await flushQueue();
          }
        } catch (error, stackTrace) {
          debugPrint('TravelMate Firebase RETRY ERROR: $error');
          debugPrintStack(stackTrace: stackTrace);

          _scheduleRetry();
        }
      },
    );
  }

  Future<void> _refreshStatus() async {
    final pending = await _storage.getPendingSyncCount();

    await _publishStatus(
      online: _status.online,
      syncing: _syncing,
      pendingItems: pending,
    );
  }

  Future<void> _publishStatus({
    bool? online,
    bool? syncing,
    int? pendingItems,
  }) async {
    _status = SyncStatus(
      online: online ?? _status.online,
      syncing: syncing ?? _status.syncing,
      pendingItems: pendingItems ?? _status.pendingItems,
    );

    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }

  Future<SyncResult> flushQueue() async {
    if (_syncing || !_firebase.isInitialised) {
      return SyncResult(
        uploaded: 0,
        failed: 0,
        remaining: await _storage.getPendingSyncCount(),
      );
    }

    _syncing = true;

    await _publishStatus(syncing: true);

    var uploaded = 0;
    var failed = 0;

    try {
      final items = await _storage.getPendingSyncItems();

      debugPrint(
        'TravelMate Sync: ${items.length} pending item(s).',
      );

      for (final item in items) {
        try {
          debugPrint(
            'TravelMate Sync: uploading '
            '${item.entity}/${item.entityId}...',
          );

          await _firebase.applySyncItem(item);

          if (item.localId != null) {
            await _storage.removeSyncItem(item.localId!);
          }

          uploaded++;

          debugPrint(
            'TravelMate Sync: uploaded '
            '${item.entity}/${item.entityId}.',
          );
        } catch (error, stackTrace) {
          failed++;

          debugPrint(
            'TravelMate Sync UPLOAD ERROR '
            '${item.entity}/${item.entityId}: $error',
          );
          debugPrintStack(stackTrace: stackTrace);

          break;
        }
      }
    } finally {
      _syncing = false;
    }

    final remaining = await _storage.getPendingSyncCount();

    await _publishStatus(
      syncing: false,
      pendingItems: remaining,
    );

    if (failed > 0) {
      _scheduleRetry();
    }

    return SyncResult(
      uploaded: uploaded,
      failed: failed,
      remaining: remaining,
    );
  }

  /// Saves locally first, then queues the corresponding Firebase operation.
  Future<void> saveModel({
    required TravelMateModel model,
    required String entity,
    required Future<void> Function() localSave,
  }) async {
    await localSave();

    await _storage.enqueueSync(
      entity: entity,
      entityId: model.id,
      action: 'upsert',
      payload: model.toMap(),
    );

    if (_firebase.isInitialised && _status.online) {
      await flushQueue();
    } else {
      await _refreshStatus();
    }
  }

  Future<void> deleteModel({
    required String entity,
    required String tripId,
    required String entityId,
    required Future<void> Function() localDelete,
  }) async {
    await localDelete();

    await _storage.enqueueSync(
      entity: entity,
      entityId: entityId,
      action: 'delete',
      payload: {
        'id': entityId,
        'tripId': tripId,
      },
    );

    if (_firebase.isInitialised && _status.online) {
      await flushQueue();
    } else {
      await _refreshStatus();
    }
  }

  /// Resolves a trip using the application's local-first strategy.
  ///
  /// 1. Look in SQLite.
  /// 2. If not found and Firebase is online, fetch it from RTDB.
  /// 3. Cache the remote trip in SQLite.
  /// 4. Return the trip.
  ///
  /// This means navigation can open trips that exist in Firebase even when
  /// they have not previously been cached on the current device.
  Future<Trip?> resolveTrip(String tripId) async {
    final cleanId = tripId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    // First choice: local SQLite.
    final localTrip = await _storage.getTrip(cleanId);

    if (localTrip != null) {
      return localTrip;
    }

    // Nothing local. Firebase is the fallback.
    if (!_firebase.isInitialised || !_status.online) {
      debugPrint(
        'TravelMate Sync: trip $cleanId not found locally '
        'and Firebase is offline.',
      );
      return null;
    }

    try {
      debugPrint(
        'TravelMate Sync: trip $cleanId not found locally. '
        'Fetching from Firebase...',
      );

      final remoteTrip = await _firebase.getTrip(cleanId);

      if (remoteTrip == null) {
        debugPrint(
          'TravelMate Sync: trip $cleanId not found in Firebase.',
        );
        return null;
      }

      // Cache the remote trip locally so subsequent navigation works
      // without another Firebase request.
      await _storage.saveTrip(remoteTrip);

      debugPrint(
        'TravelMate Sync: cached remote trip $cleanId locally.',
      );

      return remoteTrip;
    } catch (error, stackTrace) {
      debugPrint(
        'TravelMate Sync: failed to resolve trip $cleanId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      return null;
    }
  }

  StreamSubscription<Map<String, dynamic>> watchCollection({
    required String entity,
    required String tripId,
    required Future<void> Function(Map<String, dynamic> data) onChanged,
  }) {
    return _firebase
        .watchCollection(
          entity: entity,
          tripId: tripId,
        )
        .listen((data) async {
      try {
        await onChanged(data);
      } catch (error, stackTrace) {
        debugPrint(
          'TravelMate remote collection error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  StreamSubscription<Trip?> watchTrip({
    required String tripId,
    required void Function(Trip? trip) onChanged,
  }) {
    return _firebase.watchTrip(tripId).listen(onChanged);
  }

  Future<Map<String, dynamic>> pullCollection({
    required String entity,
    required String tripId,
  }) {
    return _firebase.getCollection(
      entity: entity,
      tripId: tripId,
    );
  }

  /// Converts remote collection entries into corresponding local models.
  Future<void> cacheRemoteCollection({
    required String entity,
    required String tripId,
    required Map<String, dynamic> remoteValues,
  }) async {
    for (final entry in remoteValues.entries) {
      final raw = _normaliseMap(entry.value);

      raw['id'] ??= entry.key;
      raw['tripId'] ??= tripId;

      switch (entity) {
        case 'itinerary':
        case 'itinerary_item':
        case 'itinerary_items':
          await _storage.saveItineraryItem(
            ItineraryItem.fromMap(raw),
          );
          break;

        case 'member':
        case 'members':
        case 'trip_member':
          await _storage.saveMember(
            TripMember.fromMap(raw),
          );
          break;

        case 'booking':
        case 'bookings':
          await _storage.saveBooking(
            Booking.fromMap(raw),
          );
          break;

        case 'packing':
        case 'packing_item':
        case 'packing_items':
          await _storage.savePackingItem(
            PackingItem.fromMap(raw),
          );
          break;

        case 'todo':
        case 'todos':
          await _storage.saveTodo(
            TodoItem.fromMap(raw),
          );
          break;

        case 'note':
        case 'notes':
          await _storage.saveNote(
            TravelNote.fromMap(raw),
          );
          break;

        case 'expense':
        case 'expenses':
          await _storage.saveExpense(
            Expense.fromMap(raw),
          );
          break;

        case 'road_trip_stop':
        case 'road_trip_stops':
          await _storage.saveRoadTripStop(
            RoadTripStop.fromMap(raw),
          );
          break;

        case 'location':
        case 'locations':
        case 'saved_location':
          await _storage.saveLocation(
            SavedLocation.fromMap(raw),
          );
          break;

        default:
          throw ArgumentError(
            'Unsupported cache entity: $entity',
          );
      }
    }
  }

  Map<String, dynamic> _normaliseMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      );
    }

    return <String, dynamic>{};
  }
}

class SyncStatus {
  final bool online;
  final bool syncing;
  final int pendingItems;

  const SyncStatus({
    required this.online,
    required this.syncing,
    required this.pendingItems,
  });
}

class SyncResult {
  final int uploaded;
  final int failed;
  final int remaining;

  const SyncResult({
    required this.uploaded,
    required this.failed,
    required this.remaining,
  });
}