import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'models.dart';
import 'firebase_options.dart';

/// Firebase Realtime Database layer for shared TravelMate trip data.
///
/// Private document bytes are deliberately not uploaded here.
/// PDFs, tickets, photos and similar files remain in the local
/// TravelMate folder.
///
/// Firebase stores:
/// - Trip information
/// - Itinerary information
/// - Members
/// - Bookings metadata
/// - Packing items
/// - To-do items
/// - Travel notes
/// - Expenses
/// - Road trip stops
/// - Saved locations
///
/// Actual private/local files remain on the device.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseDatabase? _database;

  bool _initialised = false;

  /// Initialise Firebase Realtime Database.
  Future<void> initialise() async {
    if (_initialised) {
      return;
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _database = FirebaseDatabase.instance;

    // Keep Firebase RTDB data available locally when possible.
    _database!.setPersistenceEnabled(true);

    _initialised = true;
  }

  /// Whether Firebase has been successfully initialised.
  bool get isInitialised {
    return _initialised && _database != null;
  }

  /// Returns the Firebase Database instance.
  FirebaseDatabase get database {
    final value = _database;

    if (value == null) {
      throw StateError(
        'FirebaseService is not initialised. '
        'Call FirebaseService.instance.initialise() first.',
      );
    }

    return value;
  }

  /// Creates a Firebase database reference.
  DatabaseReference ref(String path) {
    return database.ref(path);
  }

  // ---------------------------------------------------------------------------
  // Generic entity operations
  // ---------------------------------------------------------------------------

  /// Creates/replaces an entity in Firebase.
  Future<void> setEntity({
    required String entity,
    required String tripId,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final path = _entityPath(
      entity,
      tripId,
      entityId,
    );

    await ref(path).set(data);
  }

  /// Updates fields of an existing entity in Firebase.
  Future<void> updateEntity({
    required String entity,
    required String tripId,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final path = _entityPath(
      entity,
      tripId,
      entityId,
    );

    await ref(path).update(data);
  }

  /// Deletes an entity from Firebase.
  Future<void> deleteEntity({
    required String entity,
    required String tripId,
    required String entityId,
  }) async {
    final path = _entityPath(
      entity,
      tripId,
      entityId,
    );

    await ref(path).remove();
  }

  /// Builds the Firebase path for an entity.
  ///
  /// Root Trip:
  ///
  /// trips/<tripId>
  ///
  /// Child entity:
  ///
  /// trips/<tripId>/<collection>/<entityId>
  String _entityPath(
    String entity,
    String tripId,
    String entityId,
  ) {
    final collection = _collectionFor(entity);

    if (collection == 'trips') {
      return 'trips/$tripId';
    }

    return 'trips/$tripId/$collection/$entityId';
  }

  /// Converts different entity names used throughout the app
  /// into one Firebase collection name.
  String _collectionFor(String entity) {
    switch (entity) {
      case 'trip':
      case 'trips':
        return 'trips';

      case 'itinerary':
      case 'itinerary_item':
      case 'itinerary_items':
        return 'itinerary';

      case 'member':
      case 'members':
      case 'trip_member':
        return 'members';

      case 'booking':
      case 'bookings':
        return 'bookings';

      case 'packing':
      case 'packing_item':
      case 'packing_items':
        return 'packing';

      case 'todo':
      case 'todos':
        return 'todos';

      case 'note':
      case 'notes':
        return 'notes';

      case 'expense':
      case 'expenses':
        return 'expenses';

      case 'road_trip_stop':
      case 'road_trip_stops':
        return 'roadTripStops';

      case 'location':
      case 'locations':
      case 'saved_location':
        return 'locations';

      default:
        throw ArgumentError(
          'Unsupported Firebase entity: $entity',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  /// Saves a complete Trip.
  Future<void> saveTrip(Trip trip) {
    return setEntity(
      entity: 'trip',
      tripId: trip.id,
      entityId: trip.id,
      data: trip.toMap(),
    );
  }

  /// Deletes a complete Trip.
  Future<void> deleteTrip(String tripId) {
    return ref('trips/$tripId').remove();
  }

  /// Gets one Trip from Firebase.
  Future<Trip?> getTrip(String tripId) async {
    final snapshot = await ref(
      'trips/$tripId',
    ).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final data = _asMap(snapshot.value);

    // Make older Firebase records compatible.
    data['id'] ??= tripId;
    data['tripId'] ??= tripId;

    return Trip.fromMap(data);
  }

  /// Gets all Trips from Firebase.
  Future<List<Trip>> getTrips() async {
    final snapshot = await ref('trips').get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final map = _asMap(snapshot.value);

    return map.entries.map((entry) {
      final data = _asMap(entry.value);

      // The Firebase key is the Trip ID.
      data['id'] ??= entry.key;
      data['tripId'] ??= entry.key;

      return Trip.fromMap(data);
    }).toList();
  }

  /// Watches one Trip for real-time changes.
  Stream<Trip?> watchTrip(String tripId) {
    return ref('trips/$tripId').onValue.map(
      (event) {
        if (!event.snapshot.exists ||
            event.snapshot.value == null) {
          return null;
        }

        final data = _asMap(
          event.snapshot.value,
        );

        data['id'] ??= tripId;
        data['tripId'] ??= tripId;

        return Trip.fromMap(data);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Generic TravelMate model operations
  // ---------------------------------------------------------------------------

  /// Saves any TravelMate model.
  Future<void> saveModel(
    TravelMateModel model,
    String entity,
  ) {
    return setEntity(
      entity: entity,
      tripId: model.tripId,
      entityId: model.id,
      data: model.toMap(),
    );
  }

  /// Deletes any TravelMate model.
  Future<void> deleteModel({
    required String entity,
    required String tripId,
    required String entityId,
  }) {
    return deleteEntity(
      entity: entity,
      tripId: tripId,
      entityId: entityId,
    );
  }

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  /// Gets a complete Firebase collection for a Trip.
  Future<Map<String, dynamic>> getCollection({
    required String entity,
    required String tripId,
  }) async {
    final collection = _collectionFor(entity);

    final snapshot = await ref(
      'trips/$tripId/$collection',
    ).get();

    if (!snapshot.exists || snapshot.value == null) {
      return <String, dynamic>{};
    }

    return _asMap(snapshot.value);
  }

  /// Watches a Firebase collection for real-time changes.
  Stream<Map<String, dynamic>> watchCollection({
    required String entity,
    required String tripId,
  }) {
    final collection = _collectionFor(entity);

    return ref(
      'trips/$tripId/$collection',
    ).onValue.map(
      (event) {
        if (!event.snapshot.exists ||
            event.snapshot.value == null) {
          return <String, dynamic>{};
        }

        return _asMap(
          event.snapshot.value,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Emits true when Firebase has an active connection.
  Stream<bool> get connectionStream {
    return ref('.info/connected').onValue.map(
      (event) {
        return event.snapshot.value == true;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sync queue
  // ---------------------------------------------------------------------------

  /// Applies one pending local sync item to Firebase.
  ///
  /// IMPORTANT:
  ///
  /// For a Trip:
  ///
  /// entity   = trip
  /// entityId = Trip.id
  ///
  /// Therefore entityId is also the tripId.
  ///
  /// For child entities:
  ///
  /// payload['tripId']
  ///
  /// contains the parent Trip ID.
  ///
  /// This logic also repairs older Trip queue entries that were created
  /// before Trip.toMap() included the tripId field.
  Future<void> applySyncItem(
    SyncQueueItem item,
  ) async {
    final payload = item.payloadMap();

    final bool isTripEntity =
        item.entity == 'trip' ||
        item.entity == 'trips';

    late final String tripId;

    if (isTripEntity) {
      // A Trip's entityId is its own Trip ID.
      tripId = item.entityId;

      // Repair old queue records.
      payload['id'] ??= item.entityId;
      payload['tripId'] ??= item.entityId;
    } else {
      // Child entities must contain their parent Trip ID.
      final value = payload['tripId']?.toString();

      if (value == null || value.isEmpty) {
        throw StateError(
          'Sync item ${item.localId ?? item.entityId} '
          'has no tripId.',
        );
      }

      tripId = value;
    }

    // Handle deletion.
    if (item.action == 'delete') {
      await deleteEntity(
        entity: item.entity,
        tripId: tripId,
        entityId: item.entityId,
      );

      return;
    }

    // Handle create/update.
    await setEntity(
      entity: item.entity,
      tripId: tripId,
      entityId: item.entityId,
      data: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts Firebase's dynamic map format into
  /// Map<String, dynamic>.
  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return value.map(
        (key, value) {
          return MapEntry(
            key.toString(),
            value,
          );
        },
      );
    }

    return <String, dynamic>{};
  }
}