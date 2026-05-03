import 'package:cloud_functions/cloud_functions.dart';
import '../models/activity_model.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ── Call the itinerary optimizer Cloud Function 
  /// Sends activity list + budget constraint to the Cloud Function.


  Future<OptimizerResult> optimizeItinerary({
    required String tripId,
    required List<ActivityModel> activities,
    required double budget,
  }) async {
    try {
      final callable = _functions.httpsCallable('optimizeItinerary');

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
                  'scheduledDate': a.scheduledDate.toIso8601String(),
                  'orderIndex': a.orderIndex,
                })
            .toList(),
      };

      final result = await callable.call(payload);
      final data = result.data as Map<String, dynamic>;

      return OptimizerResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Optimizer error: ${e.message}');
    }
  }

  /// Triggers FCM notifications to all trip members.
  Future<void> sendTripNotification({
    required String tripId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendTripNotification');
      await callable.call({
        'tripId': tripId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Notification error: ${e.message}');
    }
  }
}

//Optimizer result model
class OptimizerResult {
  final List<OptimizedActivity> orderedActivities;
  final double totalCost;
  final bool withinBudget;

  OptimizerResult({
    required this.orderedActivities,
    required this.totalCost,
    required this.withinBudget,
  });

  factory OptimizerResult.fromMap(Map<String, dynamic> data) {
    final list = data['orderedActivities'] as List<dynamic>;
    return OptimizerResult(
      orderedActivities:
          list.map((a) => OptimizedActivity.fromMap(a as Map<String, dynamic>)).toList(),
      totalCost: (data['totalCost'] ?? 0).toDouble(),
      withinBudget: data['withinBudget'] ?? true,
    );
  }
}

class OptimizedActivity {
  final String activityId;
  final String name;
  final int newIndex;
  final int oldIndex;
  final String reason; // Plain-language explanation for the UI

  OptimizedActivity({
    required this.activityId,
    required this.name,
    required this.newIndex,
    required this.oldIndex,
    required this.reason,
  });

  factory OptimizedActivity.fromMap(Map<String, dynamic> data) {
    return OptimizedActivity(
      activityId: data['activityId'] ?? '',
      name: data['name'] ?? '',
      newIndex: data['newIndex'] ?? 0,
      oldIndex: data['oldIndex'] ?? 0,
      reason: data['reason'] ?? '',
    );
  }

  bool get wasMoved => newIndex != oldIndex;
}

