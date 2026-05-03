import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

// Result of a single optimizer move
class OptimizerResult {
  final String activityId;
  final String activityName;
  final int originalIndex;
  final int newIndex;
  final double score;
  final String reason; // plain-language explanation

  OptimizerResult({
    required this.activityId,
    required this.activityName,
    required this.originalIndex,
    required this.newIndex,
    required this.score,
    required this.reason,
  });

  factory OptimizerResult.fromMap(Map<String, dynamic> data) {
    return OptimizerResult(
      activityId: data['activityId'] ?? '',
      activityName: data['activityName'] ?? '',
      originalIndex: data['originalIndex'] ?? 0,
      newIndex: data['newIndex'] ?? 0,
      score: (data['score'] ?? 0).toDouble(),
      reason: data['reason'] ?? '',
    );
  }
}

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Call the itinerary optimizer Cloud Function
  // Returns: ordered activity list + per-move explanation
  Future<({
    List<ActivityModel> optimizedActivities,
    List<OptimizerResult> moves,
  })> optimizeItinerary({
    required String tripId,
    required List<ActivityModel> activities,
    required double budget,
  }) async {
    final callable =
        _functions.httpsCallable('optimizeItinerary');

    final payload = {
      'tripId': tripId,
      'budget': budget,
      'activities': activities
          .map((a) => {
                'activityId': a.activityId,
                'name': a.name,
                'location': a.location,
                'openHours': a.openHours,
                'cost': a.cost,
                'orderIndex': a.orderIndex,
              })
          .toList(),
    };

    final result = await callable.call(payload);
    final data = Map<String, dynamic>.from(result.data as Map);

    // Parse returned optimized order
    final rawActivities =
        List<Map<String, dynamic>>.from(data['optimizedActivities'] as List);
    final rawMoves =
        List<Map<String, dynamic>>.from(data['moves'] as List);

    // Map optimized order back to full ActivityModel objects
    final Map<String, ActivityModel> activityMap = {
      for (final a in activities) a.activityId: a,
    };

    final optimizedActivities = rawActivities
        .map((r) {
          final id = r['activityId'] as String;
          final newIdx = r['newIndex'] as int;
          return activityMap[id]?.copyWith(orderIndex: newIdx);
        })
        .whereType<ActivityModel>()
        .toList();

    final moves =
        rawMoves.map((m) => OptimizerResult.fromMap(m)).toList();

    return (optimizedActivities: optimizedActivities, moves: moves);
  }

  // Register FCM token for the current user so the Cloud Function
  // can send push notifications to this device
  Future<void> registerFcmToken(String uid) async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });

    // Refresh token listener
    _messaging.onTokenRefresh.listen((newToken) async {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      });
    });
  }

  // Unregister FCM token on sign-out
  Future<void> unregisterFcmToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }
}