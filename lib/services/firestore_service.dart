import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_model.dart';
import '../models/activity_model.dart';
import '../models/packing_models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // TRIPS
  

  Future<TripModel> createTrip({
    required String hostUid,
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final tripId = _uuid.v4();
    final trip = TripModel(
      tripId: tripId,
      name: name,
      destination: destination,
      memberUids: [hostUid],
      hostUid: hostUid,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();

    // Create trip document
    batch.set(_db.collection('trips').doc(tripId), trip.toMap());

    // Add tripId to user's tripIds array
    batch.update(_db.collection('users').doc(hostUid), {
      'tripIds': FieldValue.arrayUnion([tripId]),
    });

    // Create empty packing list for this trip
    batch.set(_db.collection('packingLists').doc(tripId), {'items': []});

    // Create empty checklist for this trip
    batch.set(_db.collection('checklists').doc(tripId), {'tasks': []});

    await batch.commit();
    return trip;
  }

  /// Stream a single trip in real time
  Stream<TripModel?> streamTrip(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots().map(
          (doc) => doc.exists ? TripModel.fromDoc(doc) : null,
        );
  }

  /// Stream all trips for a user
  Stream<List<TripModel>> streamUserTrips(String uid) {
    return _db
        .collection('trips')
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TripModel.fromDoc).toList());
  }

  /// Add a member to a trip
  Future<void> addMemberToTrip(String tripId, String newMemberUid) async {
    final batch = _db.batch();
    batch.update(_db.collection('trips').doc(tripId), {
      'memberUids': FieldValue.arrayUnion([newMemberUid]),
    });
    batch.update(_db.collection('users').doc(newMemberUid), {
      'tripIds': FieldValue.arrayUnion([tripId]),
    });
    await batch.commit();
  }

  /// Update optimized activity order
  Future<void> updateOptimizedOrder(
      String tripId, List<String> orderedActivityIds) async {
    await _db.collection('trips').doc(tripId).update({
      'optimizedOrder': orderedActivityIds,
    });
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId, List<String> memberUids) async {
    final batch = _db.batch();

    batch.delete(_db.collection('trips').doc(tripId));
    batch.delete(_db.collection('packingLists').doc(tripId));
    batch.delete(_db.collection('checklists').doc(tripId));

    for (final uid in memberUids) {
      batch.update(_db.collection('users').doc(uid), {
        'tripIds': FieldValue.arrayRemove([tripId]),
      });
    }

    await batch.commit();
  }

  // ACTIVITIES


  /// Add an activity to a trip
  Future<ActivityModel> addActivity({
    required String tripId,
    required String name,
    required String location,
    required String openHours,
    required double cost,
    required DateTime scheduledDate,
    List<String> tags = const [],
    String? imageUrl,
  }) async {
    final activityId = _uuid.v4();

    // Get current activity count for ordering
    final existing = await _db
        .collection('activities')
        .where('tripId', isEqualTo: tripId)
        .get();

    final activity = ActivityModel(
      activityId: activityId,
      tripId: tripId,
      name: name,
      location: location,
      openHours: openHours,
      cost: cost,
      imageUrl: imageUrl,
      tags: tags,
      scheduledDate: scheduledDate,
      orderIndex: existing.docs.length,
    );

    await _db
        .collection('activities')
        .doc(activityId)
        .set(activity.toMap());

    return activity;
  }

  /// Stream activities for a trip, ordered by orderIndex
  Stream<List<ActivityModel>> streamActivities(String tripId) {
    return _db
        .collection('activities')
        .where('tripId', isEqualTo: tripId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snap) => snap.docs.map(ActivityModel.fromDoc).toList());
  }

  /// Update activity order after drag-and-drop reorder
  Future<void> reorderActivities(
      String tripId, List<ActivityModel> reorderedList) async {
    final batch = _db.batch();
    for (int i = 0; i < reorderedList.length; i++) {
      batch.update(
        _db.collection('activities').doc(reorderedList[i].activityId),
        {'orderIndex': i},
      );
    }
    await batch.commit();
  }

  /// Delete an activity
  Future<void> deleteActivity(String activityId) async {
    await _db.collection('activities').doc(activityId).delete();
  }

  // PACKING LIST  (uses Firestore transactions for concurrent safety)

  /// Stream packing list in real time
  Stream<PackingListModel?> streamPackingList(String tripId) {
    return _db.collection('packingLists').doc(tripId).snapshots().map(
          (doc) => doc.exists ? PackingListModel.fromDoc(doc) : null,
        );
  }

  /// Add item to packing list
  Future<void> addPackingItem(String tripId, String itemName) async {
    final itemId = _uuid.v4();
    await _db.collection('packingLists').doc(tripId).update({
      'items': FieldValue.arrayUnion([
        {'itemId': itemId, 'name': itemName, 'assignedTo': null, 'checked': false}
      ]),
    });
  }

  /// Toggle packing item checked — uses TRANSACTION to prevent conflicts
  /// when multiple users check items simultaneously
  Future<void> togglePackingItem(String tripId, String itemId) async {
    final docRef = _db.collection('packingLists').doc(tripId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((i) => Map<String, dynamic>.from(i)),
      );

      final index = items.indexWhere((i) => i['itemId'] == itemId);
      if (index == -1) return;

      // Flip the checked state atomically
      items[index]['checked'] = !(items[index]['checked'] as bool);

      transaction.update(docRef, {'items': items});
    });
  }

  /// Assign a packing item to a member — also uses transaction
  Future<void> assignPackingItem(
      String tripId, String itemId, String memberUid) async {
    final docRef = _db.collection('packingLists').doc(tripId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((i) => Map<String, dynamic>.from(i)),
      );

      final index = items.indexWhere((i) => i['itemId'] == itemId);
      if (index == -1) return;

      items[index]['assignedTo'] = memberUid;
      transaction.update(docRef, {'items': items});
    });
  }

  /// Remove packing item
  Future<void> removePackingItem(
      String tripId, Map<String, dynamic> itemMap) async {
    await _db.collection('packingLists').doc(tripId).update({
      'items': FieldValue.arrayRemove([itemMap]),
    });
  }

  // CHECKLIST

  /// Stream checklist in real time
  Stream<ChecklistModel?> streamChecklist(String tripId) {
    return _db.collection('checklists').doc(tripId).snapshots().map(
          (doc) => doc.exists ? ChecklistModel.fromDoc(doc) : null,
        );
  }

  /// Add a checklist task
  Future<void> addChecklistTask(String tripId, String title,
      {DateTime? dueDate}) async {
    final taskId = _uuid.v4();
    final taskMap = {
      'taskId': taskId,
      'title': title,
      'completed': false,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
    };
    await _db.collection('checklists').doc(tripId).update({
      'tasks': FieldValue.arrayUnion([taskMap]),
    });
  }

  /// Toggle checklist task completed
  Future<void> toggleChecklistTask(String tripId, String taskId) async {
    final docRef = _db.collection('checklists').doc(tripId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final tasks = List<Map<String, dynamic>>.from(
        (data['tasks'] as List).map((t) => Map<String, dynamic>.from(t)),
      );

      final index = tasks.indexWhere((t) => t['taskId'] == taskId);
      if (index == -1) return;

      tasks[index]['completed'] = !(tasks[index]['completed'] as bool);
      transaction.update(docRef, {'tasks': tasks});
    });
  }
}
