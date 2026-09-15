import 'dart:convert';

String dateToJson(DateTime value) {
  return value.toUtc().toIso8601String();
}

DateTime? dateFromJson(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString())?.toLocal();
}

String encodeMap(Map<String, dynamic> value) {
  return jsonEncode(value);
}

Map<String, dynamic> decodeMap(Object? value) {
  if (value == null) {
    return <String, dynamic>{};
  }

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

  final text = value.toString().trim();

  if (text.isEmpty) {
    return <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(text);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return <String, dynamic>{};
  }

  return <String, dynamic>{};
}

abstract class TravelMateModel {
  String get id;

  String get tripId;

  Map<String, dynamic> toMap();
}

class Trip implements TravelMateModel {
  @override
  final String id;

  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverImageUrl;
  final String description;
  final String status;
  final String ownerId;
  final String travelType;
  final int travellerCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trip({
    required this.id,
    required this.title,
    required this.destination,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
    this.description = '',
    this.status = 'planning',
    this.ownerId = '',
    this.travelType = 'leisure',
    this.travellerCount = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      destination: map['destination']?.toString() ?? '',
      startDate: dateFromJson(map['startDate']),
      endDate: dateFromJson(map['endDate']),
      coverImageUrl: map['coverImageUrl']?.toString(),
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'planning',
      ownerId: map['ownerId']?.toString() ?? '',
      travelType: map['travelType']?.toString() ?? 'leisure',
      travellerCount:
          (map['travellerCount'] as num?)?.toInt() ?? 1,
      createdAt:
          dateFromJson(map['createdAt']) ?? DateTime.now(),
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Trip copyWith({
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? coverImageUrl,
    String? description,
    String? status,
    String? ownerId,
    String? travelType,
    int? travellerCount,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      description: description ?? this.description,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      travelType: travelType ?? this.travelType,
      travellerCount:
          travellerCount ?? this.travellerCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String get tripId => id;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': id,
      'title': title,
      'destination': destination,
      'startDate':
          startDate == null ? null : dateToJson(startDate!),
      'endDate':
          endDate == null ? null : dateToJson(endDate!),
      'coverImageUrl': coverImageUrl,
      'description': description,
      'status': status,
      'ownerId': ownerId,
      'travelType': travelType,
      'travellerCount': travellerCount,
      'createdAt': dateToJson(createdAt),
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class ItineraryItem implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final int dayNumber;
  final String title;
  final String type;
  final String time;
  final String location;
  final String note;
  final String? imageUrl;
  final String? mapsUrl;
  final int sortOrder;
  final DateTime updatedAt;

  ItineraryItem({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.title,
    this.type = 'activity',
    this.time = '',
    this.location = '',
    this.note = '',
    this.imageUrl,
    this.mapsUrl,
    this.sortOrder = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  ItineraryItem copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    String? title,
    String? type,
    String? time,
    String? location,
    String? note,
    String? imageUrl,
    String? mapsUrl,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      type: type ?? this.type,
      time: time ?? this.time,
      location: location ?? this.location,
      note: note ?? this.note,
      imageUrl: imageUrl ?? this.imageUrl,
      mapsUrl: mapsUrl ?? this.mapsUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory ItineraryItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return ItineraryItem(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      dayNumber:
          (map['dayNumber'] as num?)?.toInt() ?? 1,
      title: map['title']?.toString() ?? '',
      type: map['type']?.toString() ?? 'activity',
      time: map['time']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      mapsUrl: map['mapsUrl']?.toString(),
      sortOrder:
          (map['sortOrder'] as num?)?.toInt() ?? 0,
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'dayNumber': dayNumber,
      'title': title,
      'type': type,
      'time': time,
      'location': location,
      'note': note,
      'imageUrl': imageUrl,
      'mapsUrl': mapsUrl,
      'sortOrder': sortOrder,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class TripMember implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String status;
  final DateTime joinedAt;

  TripMember({
    required this.id,
    required this.tripId,
    required this.name,
    this.email = '',
    this.role = 'member',
    this.avatarUrl,
    this.status = 'active',
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  factory TripMember.fromMap(
    Map<String, dynamic> map,
  ) {
    return TripMember(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? 'member',
      avatarUrl: map['avatarUrl']?.toString(),
      status: map['status']?.toString() ?? 'active',
      joinedAt:
          dateFromJson(map['joinedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'name': name,
      'email': email,
      'role': role,
      'avatarUrl': avatarUrl,
      'status': status,
      'joinedAt': dateToJson(joinedAt),
    };
  }
}

class Booking implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String type;
  final String title;
  final String referenceNumber;
  final String fileName;
  final String localPath;
  final String? cloudUrl;
  final DateTime? bookingDate;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.tripId,
    required this.type,
    required this.title,
    this.referenceNumber = '',
    this.fileName = '',
    this.localPath = '',
    this.cloudUrl,
    this.bookingDate,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Booking.fromMap(
    Map<String, dynamic> map,
  ) {
    return Booking(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'other',
      title: map['title']?.toString() ?? '',
      referenceNumber:
          map['referenceNumber']?.toString() ?? '',
      fileName:
          map['fileName']?.toString() ?? '',
      localPath:
          map['localPath']?.toString() ?? '',
      cloudUrl: map['cloudUrl']?.toString(),
      bookingDate:
          dateFromJson(map['bookingDate']),
      notes: map['notes']?.toString() ?? '',
      createdAt:
          dateFromJson(map['createdAt']) ?? DateTime.now(),
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type,
      'title': title,
      'referenceNumber': referenceNumber,
      'fileName': fileName,
      'localPath': localPath,
      'cloudUrl': cloudUrl,
      'bookingDate': bookingDate == null
          ? null
          : dateToJson(bookingDate!),
      'notes': notes,
      'createdAt': dateToJson(createdAt),
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class PackingItem implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String category;
  final String name;
  final int quantity;
  final bool packed;
  final DateTime updatedAt;

  PackingItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.name,
    this.quantity = 1,
    this.packed = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory PackingItem.fromMap(
    Map<String, dynamic> map,
  ) {
    final packedValue = map['packed'];

    final bool packed = packedValue == true ||
        (packedValue is num && packedValue.toInt() == 1);

    return PackingItem(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      category:
          map['category']?.toString() ?? 'General',
      name: map['name']?.toString() ?? '',
      quantity:
          (map['quantity'] as num?)?.toInt() ?? 1,
      packed: packed,
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'category': category,
      'name': name,
      'quantity': quantity,
      'packed': packed,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class TodoItem implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String title;
  final String description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime updatedAt;

  TodoItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'normal',
    this.dueDate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory TodoItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return TodoItem(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description:
          map['description']?.toString() ?? '',
      status:
          map['status']?.toString() ?? 'todo',
      priority:
          map['priority']?.toString() ?? 'normal',
      dueDate: dateFromJson(map['dueDate']),
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'dueDate':
          dueDate == null ? null : dateToJson(dueDate!),
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class TravelNote implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String title;
  final String content;
  final String category;
  final DateTime updatedAt;

  TravelNote({
    required this.id,
    required this.tripId,
    required this.title,
    this.content = '',
    this.category = 'General',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory TravelNote.fromMap(
    Map<String, dynamic> map,
  ) {
    return TravelNote(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content:
          map['content']?.toString() ?? '',
      category:
          map['category']?.toString() ?? 'General',
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'content': content,
      'category': category,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class Expense implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String title;
  final double amount;
  final String currency;
  final String category;
  final String paidBy;
  final DateTime date;
  final String note;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    this.currency = 'INR',
    this.category = 'Other',
    this.paidBy = '',
    DateTime? date,
    this.note = '',
    DateTime? updatedAt,
  })  : date = date ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Expense.fromMap(
    Map<String, dynamic> map,
  ) {
    return Expense(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount:
          (map['amount'] as num?)?.toDouble() ?? 0,
      currency:
          map['currency']?.toString() ?? 'INR',
      category:
          map['category']?.toString() ?? 'Other',
      paidBy:
          map['paidBy']?.toString() ?? '',
      date:
          dateFromJson(map['date']) ?? DateTime.now(),
      note:
          map['note']?.toString() ?? '',
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'title': title,
      'amount': amount,
      'currency': currency,
      'category': category,
      'paidBy': paidBy,
      'date': dateToJson(date),
      'note': note,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class RoadTripStop implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final int sequence;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final int stayMinutes;
  final String note;
  final DateTime updatedAt;

  RoadTripStop({
    required this.id,
    required this.tripId,
    required this.sequence,
    required this.name,
    this.address = '',
    this.latitude,
    this.longitude,
    this.stayMinutes = 0,
    this.note = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory RoadTripStop.fromMap(
    Map<String, dynamic> map,
  ) {
    return RoadTripStop(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      sequence:
          (map['sequence'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      address:
          map['address']?.toString() ?? '',
      latitude:
          (map['latitude'] as num?)?.toDouble(),
      longitude:
          (map['longitude'] as num?)?.toDouble(),
      stayMinutes:
          (map['stayMinutes'] as num?)?.toInt() ?? 0,
      note:
          map['note']?.toString() ?? '',
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'sequence': sequence,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'stayMinutes': stayMinutes,
      'note': note,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class SavedLocation implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final String category;
  final DateTime updatedAt;

  SavedLocation({
    required this.id,
    required this.tripId,
    required this.name,
    this.address = '',
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.category = 'Place',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory SavedLocation.fromMap(
    Map<String, dynamic> map,
  ) {
    return SavedLocation(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address:
          map['address']?.toString() ?? '',
      latitude:
          (map['latitude'] as num?)?.toDouble(),
      longitude:
          (map['longitude'] as num?)?.toDouble(),
      mapsUrl:
          map['mapsUrl']?.toString(),
      category:
          map['category']?.toString() ?? 'Place',
      updatedAt:
          dateFromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'mapsUrl': mapsUrl,
      'category': category,
      'updatedAt': dateToJson(updatedAt),
    };
  }
}

class LocalDocument implements TravelMateModel {
  @override
  final String id;

  @override
  final String tripId;

  final String fileName;
  final String localPath;
  final String mimeType;
  final int sizeBytes;
  final String category;
  final DateTime addedAt;

  LocalDocument({
    required this.id,
    required this.tripId,
    required this.fileName,
    required this.localPath,
    this.mimeType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.category = 'Travel document',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory LocalDocument.fromMap(
    Map<String, dynamic> map,
  ) {
    return LocalDocument(
      id: map['id']?.toString() ?? '',
      tripId: map['tripId']?.toString() ?? '',
      fileName:
          map['fileName']?.toString() ?? '',
      localPath:
          map['localPath']?.toString() ?? '',
      mimeType:
          map['mimeType']?.toString() ??
              'application/octet-stream',
      sizeBytes:
          (map['sizeBytes'] as num?)?.toInt() ?? 0,
      category:
          map['category']?.toString() ??
              'Travel document',
      addedAt:
          dateFromJson(map['addedAt']) ??
              DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'fileName': fileName,
      'localPath': localPath,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'category': category,
      'addedAt': dateToJson(addedAt),
    };
  }
}

class SyncQueueItem {
  final int? localId;
  final String entity;
  final String entityId;
  final String action;
  final String payload;
  final DateTime createdAt;

  SyncQueueItem({
    this.localId,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SyncQueueItem.fromMap(
    Map<String, dynamic> map,
  ) {
    return SyncQueueItem(
      localId:
          (map['localId'] as num?)?.toInt(),
      entity:
          map['entity']?.toString() ?? '',
      entityId:
          map['entityId']?.toString() ?? '',
      action:
          map['action']?.toString() ?? 'upsert',
      payload:
          map['payload']?.toString() ?? '{}',
      createdAt:
          dateFromJson(map['createdAt']) ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'entity': entity,
      'entityId': entityId,
      'action': action,
      'payload': payload,
      'createdAt': dateToJson(createdAt),
    };
  }

  Map<String, dynamic> payloadMap() {
    return decodeMap(payload);
  }
}