import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

/// Local-first SQLite layer for TravelMate.
///
/// Structured data is cached here so the app remains useful offline.
/// User-selected documents are copied into the app's TravelMate folder and
/// only their metadata is placed in SQLite.
///
/// Firebase synchronisation is handled by SyncService.
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const _databaseName = 'travelmate.db';

  // Version 3 adds tripId to the trips table.
  static const _databaseVersion = 3;

  Database? _database;
  Directory? _documentsDirectory;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> initialise() async {
    if (_database != null) return;

    if (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasePath = await getDatabasesPath();

    _database = await openDatabase(
      '$databasePath/$_databaseName',
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: (db, oldVersion, newVersion) async {
        // -------------------------------------------------------------------
        // Version 2
        // -------------------------------------------------------------------
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE trips "
            "ADD COLUMN travelType TEXT NOT NULL DEFAULT 'leisure'",
          );

          await db.execute(
            "ALTER TABLE trips "
            "ADD COLUMN travellerCount INTEGER NOT NULL DEFAULT 1",
          );
        }

        // -------------------------------------------------------------------
        // Version 3
        //
        // Trip.toMap() now contains tripId.
        // Existing databases therefore need the new SQLite column.
        // -------------------------------------------------------------------
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE trips "
            "ADD COLUMN tripId TEXT NOT NULL DEFAULT ''",
          );

          // Every Trip uses its own id as its tripId.
          //
          // Existing local records therefore become:
          //
          // id     = abc123
          // tripId  = abc123
          //
          await db.execute(
            "UPDATE trips "
            "SET tripId = id "
            "WHERE tripId = '' OR tripId IS NULL",
          );
        }
      },
    );

    final appDirectory =
        await getApplicationDocumentsDirectory();

    _documentsDirectory = Directory(
      '${appDirectory.path}'
      '${Platform.pathSeparator}'
      'TravelMate',
    );

    if (!await _documentsDirectory!.exists()) {
      await _documentsDirectory!.create(
        recursive: true,
      );
    }
  }

  Future<Database> get database async {
    await initialise();
    return _database!;
  }

  Future<Directory> get documentsDirectory async {
    await initialise();
    return _documentsDirectory!;
  }

  // ---------------------------------------------------------------------------
  // Database creation
  // ---------------------------------------------------------------------------

  Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        title TEXT NOT NULL,
        destination TEXT NOT NULL,
        startDate TEXT,
        endDate TEXT,
        coverImageUrl TEXT,
        description TEXT,
        status TEXT NOT NULL,
        ownerId TEXT,
        travelType TEXT NOT NULL,
        travellerCount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE itinerary_items (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        dayNumber INTEGER NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        time TEXT,
        location TEXT,
        note TEXT,
        imageUrl TEXT,
        mapsUrl TEXT,
        sortOrder INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_members (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL,
        avatarUrl TEXT,
        status TEXT NOT NULL,
        joinedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bookings (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        referenceNumber TEXT,
        fileName TEXT,
        localPath TEXT,
        cloudUrl TEXT,
        bookingDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE packing_items (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        packed INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL,
        priority TEXT NOT NULL,
        dueDate TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        category TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        paidBy TEXT,
        date TEXT NOT NULL,
        note TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE road_trip_stops (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL,
        longitude REAL,
        stayMinutes INTEGER NOT NULL,
        note TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_locations (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL,
        longitude REAL,
        mapsUrl TEXT,
        category TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_documents (
        id TEXT PRIMARY KEY,
        tripId TEXT NOT NULL,
        fileName TEXT NOT NULL,
        localPath TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        sizeBytes INTEGER NOT NULL,
        category TEXT NOT NULL,
        addedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // -------------------------------------------------------------------------
    // Indexes
    // -------------------------------------------------------------------------

    await db.execute(
      'CREATE INDEX idx_itinerary_trip_day '
      'ON itinerary_items(tripId, dayNumber)',
    );

    await db.execute(
      'CREATE INDEX idx_members_trip '
      'ON trip_members(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_bookings_trip '
      'ON bookings(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_packing_trip '
      'ON packing_items(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_todos_trip_status '
      'ON todos(tripId, status)',
    );

    await db.execute(
      'CREATE INDEX idx_notes_trip '
      'ON notes(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_expenses_trip '
      'ON expenses(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_road_stops_trip '
      'ON road_trip_stops(tripId, sequence)',
    );

    await db.execute(
      'CREATE INDEX idx_locations_trip '
      'ON saved_locations(tripId)',
    );

    await db.execute(
      'CREATE INDEX idx_documents_trip '
      'ON local_documents(tripId)',
    );
  }

  // ---------------------------------------------------------------------------
  // IDs
  // ---------------------------------------------------------------------------

  String newId() {
    return DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(36);
  }

  // ---------------------------------------------------------------------------
  // Close database
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ---------------------------------------------------------------------------
  // SQLite value conversion
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _databaseValues(
    Map<String, dynamic> values,
  ) {
    final result = <String, dynamic>{};

    values.forEach((key, value) {
      if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is DateTime) {
        result[key] = dateToJson(value);
      } else if (value is Map || value is List) {
        result[key] = jsonEncode(value);
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  // ---------------------------------------------------------------------------
  // Generic model storage
  // ---------------------------------------------------------------------------

  Future<void> saveModel({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    final db = await database;

    await db.insert(
      table,
      _databaseValues(values),
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteModel(
    String table,
    String id,
  ) async {
    final db = await database;

    await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  Future<void> saveTrip(Trip trip) async {
    final updatedTrip = trip.copyWith(
      updatedAt: DateTime.now(),
    );

    await saveModel(
      table: 'trips',
      values: updatedTrip.toMap(),
    );
  }

  Future<Trip?> getTrip(String id) async {
    final db = await database;

    final rows = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Trip.fromMap(rows.first);
  }

  Future<List<Trip>> getTrips({
    String? search,
    String? status,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <Object?>[];

    if (search != null &&
        search.trim().isNotEmpty) {
      where.add(
        '(title LIKE ? OR destination LIKE ?)',
      );

      final q = '%${search.trim()}%';

      args.addAll([
        q,
        q,
      ]);
    }

    if (status != null &&
        status.isNotEmpty) {
      where.add('status = ?');
      args.add(status);
    }

    final rows = await db.query(
      'trips',
      where: where.isEmpty
          ? null
          : where.join(' AND '),
      whereArgs:
          args.isEmpty ? null : args,
      orderBy: 'updatedAt DESC',
    );

    return rows
        .map(Trip.fromMap)
        .toList();
  }

  Future<void> deleteTrip(
    String tripId,
  ) async {
    final db = await database;

    await db.transaction(
      (txn) async {
        for (final table in [
          'itinerary_items',
          'trip_members',
          'bookings',
          'packing_items',
          'todos',
          'notes',
          'expenses',
          'road_trip_stops',
          'saved_locations',
          'local_documents',
        ]) {
          await txn.delete(
            table,
            where: 'tripId = ?',
            whereArgs: [tripId],
          );
        }

        await txn.delete(
          'trips',
          where: 'id = ?',
          whereArgs: [tripId],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Itinerary
  // ---------------------------------------------------------------------------

  Future<void> saveItineraryItem(
    ItineraryItem item,
  ) =>
      saveModel(
        table: 'itinerary_items',
        values: item.toMap(),
      );

  Future<List<ItineraryItem>>
      getItineraryItems(
    String tripId, {
    int? dayNumber,
  }) async {
    final db = await database;

    final where = <String>[
      'tripId = ?',
    ];

    final args = <Object?>[
      tripId,
    ];

    if (dayNumber != null) {
      where.add(
        'dayNumber = ?',
      );

      args.add(dayNumber);
    }

    final rows = await db.query(
      'itinerary_items',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy:
          'dayNumber ASC, sortOrder ASC',
    );

    return rows
        .map(ItineraryItem.fromMap)
        .toList();
  }

  Future<void> deleteItineraryItem(
    String id,
  ) =>
      deleteModel(
        'itinerary_items',
        id,
      );

  // ---------------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------------

  Future<void> saveMember(
    TripMember member,
  ) =>
      saveModel(
        table: 'trip_members',
        values: member.toMap(),
      );

  Future<List<TripMember>> getMembers(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'trip_members',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'joinedAt ASC',
    );

    return rows
        .map(TripMember.fromMap)
        .toList();
  }

  Future<void> deleteMember(
    String id,
  ) =>
      deleteModel(
        'trip_members',
        id,
      );

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  Future<void> saveBooking(
    Booking booking,
  ) =>
      saveModel(
        table: 'bookings',
        values: booking.toMap(),
      );

  Future<List<Booking>> getBookings(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'bookings',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy:
          'bookingDate ASC, createdAt DESC',
    );

    return rows
        .map(Booking.fromMap)
        .toList();
  }

  Future<void> deleteBooking(
    String id,
  ) =>
      deleteModel(
        'bookings',
        id,
      );

  // ---------------------------------------------------------------------------
  // Packing
  // ---------------------------------------------------------------------------

  Future<void> savePackingItem(
    PackingItem item,
  ) =>
      saveModel(
        table: 'packing_items',
        values: item.toMap(),
      );

  Future<List<PackingItem>>
      getPackingItems(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'packing_items',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy:
          'category ASC, name ASC',
    );

    return rows
        .map(PackingItem.fromMap)
        .toList();
  }

  Future<void> deletePackingItem(
    String id,
  ) =>
      deleteModel(
        'packing_items',
        id,
      );

  // ---------------------------------------------------------------------------
  // Todos
  // ---------------------------------------------------------------------------

  Future<void> saveTodo(
    TodoItem item,
  ) =>
      saveModel(
        table: 'todos',
        values: item.toMap(),
      );

  Future<List<TodoItem>> getTodos(
    String tripId, {
    String? status,
  }) async {
    final db = await database;

    final where = <String>[
      'tripId = ?',
    ];

    final args = <Object?>[
      tripId,
    ];

    if (status != null &&
        status.isNotEmpty) {
      where.add(
        'status = ?',
      );

      args.add(status);
    }

    final rows = await db.query(
      'todos',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );

    return rows
        .map(TodoItem.fromMap)
        .toList();
  }

  Future<void> deleteTodo(
    String id,
  ) =>
      deleteModel(
        'todos',
        id,
      );

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<void> saveNote(
    TravelNote note,
  ) =>
      saveModel(
        table: 'notes',
        values: note.toMap(),
      );

  Future<List<TravelNote>> getNotes(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'notes',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'updatedAt DESC',
    );

    return rows
        .map(TravelNote.fromMap)
        .toList();
  }

  Future<void> deleteNote(
    String id,
  ) =>
      deleteModel(
        'notes',
        id,
      );

  // ---------------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------------

  Future<void> saveExpense(
    Expense expense,
  ) =>
      saveModel(
        table: 'expenses',
        values: expense.toMap(),
      );

  Future<List<Expense>> getExpenses(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'expenses',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'date DESC',
    );

    return rows
        .map(Expense.fromMap)
        .toList();
  }

  Future<double> getExpenseTotal(
    String tripId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM expenses '
      'WHERE tripId = ?',
      [tripId],
    );

    return (result.first['total'] as num?)
            ?.toDouble() ??
        0;
  }

  Future<void> deleteExpense(
    String id,
  ) =>
      deleteModel(
        'expenses',
        id,
      );

  // ---------------------------------------------------------------------------
  // Road trip stops
  // ---------------------------------------------------------------------------

  Future<void> saveRoadTripStop(
    RoadTripStop stop,
  ) =>
      saveModel(
        table: 'road_trip_stops',
        values: stop.toMap(),
      );

  Future<List<RoadTripStop>>
      getRoadTripStops(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'road_trip_stops',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'sequence ASC',
    );

    return rows
        .map(RoadTripStop.fromMap)
        .toList();
  }

  Future<void> deleteRoadTripStop(
    String id,
  ) =>
      deleteModel(
        'road_trip_stops',
        id,
      );

  // ---------------------------------------------------------------------------
  // Saved locations
  // ---------------------------------------------------------------------------

  Future<void> saveLocation(
    SavedLocation location,
  ) =>
      saveModel(
        table: 'saved_locations',
        values: location.toMap(),
      );

  Future<List<SavedLocation>> getLocations(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'saved_locations',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'updatedAt DESC',
    );

    return rows
        .map(SavedLocation.fromMap)
        .toList();
  }

  Future<void> deleteLocation(
    String id,
  ) =>
      deleteModel(
        'saved_locations',
        id,
      );

  // ---------------------------------------------------------------------------
  // Local files
  // ---------------------------------------------------------------------------

  Future<LocalDocument> saveLocalFile({
    required String tripId,
    required File sourceFile,
    required String category,
    String? fileName,
    String mimeType =
        'application/octet-stream',
  }) async {
    final root = await documentsDirectory;

    final tripDirectory = Directory(
      '${root.path}'
      '${Platform.pathSeparator}'
      '$tripId',
    );

    if (!await tripDirectory.exists()) {
      await tripDirectory.create(
        recursive: true,
      );
    }

    final originalName =
        fileName ??
        sourceFile.uri.pathSegments.last;

    final safeName =
        _safeFileName(originalName);

    final uniqueName =
        '${DateTime.now().microsecondsSinceEpoch}_'
        '$safeName';

    final destination = File(
      '${tripDirectory.path}'
      '${Platform.pathSeparator}'
      '$uniqueName',
    );

    final copied =
        await sourceFile.copy(
      destination.path,
    );

    final document = LocalDocument(
      id: newId(),
      tripId: tripId,
      fileName: originalName,
      localPath: copied.path,
      mimeType: mimeType,
      sizeBytes: await copied.length(),
      category: category,
    );

    await saveModel(
      table: 'local_documents',
      values: document.toMap(),
    );

    return document;
  }

  Future<List<LocalDocument>>
      getLocalFiles(
    String tripId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'local_documents',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'addedAt DESC',
    );

    return rows
        .map(LocalDocument.fromMap)
        .toList();
  }

  Future<void> deleteLocalFile(
    String id, {
    bool deleteBytes = true,
  }) async {
    final db = await database;

    final rows = await db.query(
      'local_documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    final document =
        LocalDocument.fromMap(
      rows.first,
    );

    if (deleteBytes &&
        document.localPath.isNotEmpty) {
      final file =
          File(document.localPath);

      if (await file.exists()) {
        await file.delete();
      }
    }

    await db.delete(
      'local_documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(
          RegExp(r'[<>:"/\\|?*]'),
          '_',
        )
        .trim();

    return cleaned.isEmpty
        ? 'travel_document'
        : cleaned;
  }

  Future<int> getLocalStorageBytes(
    String tripId,
  ) async {
    final files =
        await getLocalFiles(tripId);

    return files.fold<int>(
      0,
      (sum, item) =>
          sum + item.sizeBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Sync queue
  // ---------------------------------------------------------------------------

  Future<int> enqueueSync({
    required String entity,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;

    return db.insert(
      'sync_queue',
      {
        'entity': entity,
        'entityId': entityId,
        'action': action,
        'payload': jsonEncode(payload),
        'createdAt':
            dateToJson(DateTime.now()),
      },
    );
  }

  Future<List<SyncQueueItem>>
      getPendingSyncItems() async {
    final db = await database;

    final rows = await db.query(
      'sync_queue',
      orderBy:
          'createdAt ASC, localId ASC',
    );

    return rows
        .map(SyncQueueItem.fromMap)
        .toList();
  }

  Future<void> removeSyncItem(
    int localId,
  ) async {
    final db = await database;

    await db.delete(
      'sync_queue',
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count '
      'FROM sync_queue',
    );

    return (result.first['count'] as num?)
            ?.toInt() ??
        0;
  }

  // ---------------------------------------------------------------------------
  // Combined save/delete + sync queue helpers
  // ---------------------------------------------------------------------------

  Future<void> saveAndQueue({
    required String table,
    required String entity,
    required String entityId,
    required Map<String, dynamic> values,
  }) async {
    await saveModel(
      table: table,
      values: values,
    );

    await enqueueSync(
      entity: entity,
      entityId: entityId,
      action: 'upsert',
      payload: values,
    );
  }

  Future<void> deleteAndQueue({
    required String table,
    required String entity,
    required String entityId,
  }) async {
    await deleteModel(
      table,
      entityId,
    );

    await enqueueSync(
      entity: entity,
      entityId: entityId,
      action: 'delete',
      payload: {
        'id': entityId,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reactive/polling streams
  // ---------------------------------------------------------------------------

  Stream<List<TodoItem>> watchTodos(
    String tripId,
  ) async* {
    while (true) {
      yield await getTodos(tripId);

      await Future<void>.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );
    }
  }

  Stream<List<TravelNote>> watchNotes(
    String tripId,
  ) async* {
    while (true) {
      yield await getNotes(tripId);

      await Future<void>.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );
    }
  }

  Stream<List<Expense>> watchExpenses(
    String tripId,
  ) async* {
    while (true) {
      yield await getExpenses(tripId);

      await Future<void>.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );
    }
  }
}