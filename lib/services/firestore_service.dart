import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_model.dart';
import '../models/activity_model.dart';
import '../models/packing_models.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─────────────────────────────────────────
  // USERS
  // ─────────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ─────────────────────────────────────────
  // TRIPS
  // ─────────────────────────────────────────

  // Stream of all trips where uid is a member
  Stream<List<TripModel>> tripsStream(String uid) {
    return _db
        .collection('trips')
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TripModel.fromDoc(d)).toList());
  }

  // Single trip stream (for real-time overview updates)
  Stream<TripModel?> tripStream(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists ? TripModel.fromDoc(doc) : null);
  }

  // Create a new trip
  Future<String> createTrip({
    required String name,
    required String destination,
    required String hostUid,
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
    await _db.collection('trips').doc(tripId).set(trip.toMap());

    // Add tripId to user's profile
    await _db.collection('users').doc(hostUid).update({
      'tripIds': FieldValue.arrayUnion([tripId]),
    });

    // Initialize empty packing list and checklist for this trip
    await _db
        .collection('packingList')
        .doc(tripId)
        .set({'items': []});
    await _db
        .collection('checklists')
        .doc(tripId)
        .set({'tasks': []});

    return tripId;
  }

  // Update trip cover image
  Future<void> updateTripCoverImage(
      String tripId, String imageUrl) async {
    await _db
        .collection('trips')
        .doc(tripId)
        .update({'coverImageUrl': imageUrl});
  }

  // Save optimizer result to trip
  Future<void> saveOptimizedOrder(
      String tripId, List<String> orderedActivityIds) async {
    await _db.collection('trips').doc(tripId).update({
      'optimizedOrder': orderedActivityIds,
    });
  }

  // Delete trip
  Future<void> deleteTrip(String tripId, String hostUid) async {
    await _db.collection('trips').doc(tripId).delete();
    await _db.collection('users').doc(hostUid).update({
      'tripIds': FieldValue.arrayRemove([tripId]),
    });
  }

  // ─────────────────────────────────────────
  // ACTIVITIES
  // ─────────────────────────────────────────

  // Stream of activities for a trip, ordered by orderIndex
  Stream<List<ActivityModel>> activitiesStream(String tripId) {
    return _db
        .collection('activities')
        .where('tripId', isEqualTo: tripId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ActivityModel.fromDoc(d)).toList());
  }

  // Add a new activity to a trip
  Future<String> addActivity(ActivityModel activity) async {
    final activityId = _uuid.v4();
    final data = activity.toMap();
    await _db.collection('activities').doc(activityId).set(data);
    return activityId;
  }

  // Update the order of activities after drag-and-drop
  Future<void> updateActivityOrder(
      List<ActivityModel> reorderedActivities) async {
    final batch = _db.batch();
    for (int i = 0; i < reorderedActivities.length; i++) {
      final ref = _db
          .collection('activities')
          .doc(reorderedActivities[i].activityId);
      batch.update(ref, {'orderIndex': i});
    }
    await batch.commit();
  }

  // Delete an activity
  Future<void> deleteActivity(String activityId) async {
    await _db.collection('activities').doc(activityId).delete();
  }

  // Update activity image URL
  Future<void> updateActivityImage(
      String activityId, String imageUrl) async {
    await _db
        .collection('activities')
        .doc(activityId)
        .update({'imageUrl': imageUrl});
  }

  // ─────────────────────────────────────────
  // PACKING LIST
  // ─────────────────────────────────────────

  // Real-time packing list stream
  Stream<PackingListModel?> packingListStream(String tripId) {
    return _db
        .collection('packingList')
        .doc(tripId)
        .snapshots()
        .map((doc) =>
            doc.exists ? PackingListModel.fromDoc(doc) : null);
  }

  // Add item to packing list
  Future<void> addPackingItem(String tripId, String itemName) async {
    final newItem = PackingItem(
      itemId: _uuid.v4(),
      name: itemName,
    );
    await _db.collection('packingList').doc(tripId).update({
      'items': FieldValue.arrayUnion([newItem.toMap()]),
    });
  }

  // Toggle packing item checked state using Firestore transaction
  // This prevents conflicts when multiple users check items simultaneously
  Future<void> togglePackingItem(
      String tripId, String itemId, bool newChecked,
      {String? assignedTo}) async {
    final docRef = _db.collection('packingList').doc(tripId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final rawItems = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((i) => Map<String, dynamic>.from(i)),
      );

      final idx = rawItems.indexWhere((i) => i['itemId'] == itemId);
      if (idx == -1) return;

      rawItems[idx]['checked'] = newChecked;
      if (assignedTo != null) {
        rawItems[idx]['assignedTo'] = assignedTo;
      }

      transaction.update(docRef, {'items': rawItems});
    });
  }

  // Remove item from packing list
  Future<void> removePackingItem(
      String tripId, PackingItem item) async {
    await _db.collection('packingList').doc(tripId).update({
      'items': FieldValue.arrayRemove([item.toMap()]),
    });
  }

  // ─────────────────────────────────────────
  // CHECKLIST
  // ─────────────────────────────────────────

  // Real-time checklist stream
  Stream<ChecklistModel?> checklistStream(String tripId) {
    return _db
        .collection('checklists')
        .doc(tripId)
        .snapshots()
        .map((doc) =>
            doc.exists ? ChecklistModel.fromDoc(doc) : null);
  }

  // Add checklist task
  Future<void> addChecklistTask(
      String tripId, String title, DateTime? dueDate) async {
    final task = ChecklistTask(
      taskId: _uuid.v4(),
      title: title,
      dueDate: dueDate,
    );
    await _db.collection('checklists').doc(tripId).update({
      'tasks': FieldValue.arrayUnion([task.toMap()]),
    });
  }

  // Toggle checklist task completed
  Future<void> toggleChecklistTask(
      String tripId, String taskId, bool newCompleted) async {
    final docRef = _db.collection('checklists').doc(tripId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final rawTasks = List<Map<String, dynamic>>.from(
        (data['tasks'] as List).map((t) => Map<String, dynamic>.from(t)),
      );

      final idx = rawTasks.indexWhere((t) => t['taskId'] == taskId);
      if (idx == -1) return;

      rawTasks[idx]['completed'] = newCompleted;
      transaction.update(docRef, {'tasks': rawTasks});
    });
  }

  // Remove checklist task
  Future<void> removeChecklistTask(
      String tripId, ChecklistTask task) async {
    await _db.collection('checklists').doc(tripId).update({
      'tasks': FieldValue.arrayRemove([task.toMap()]),
    });
  }
}
