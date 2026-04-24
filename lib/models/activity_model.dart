import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel { 
  final String activityId; 
  final String tripId; 
  final String name; 
  final String location; 
  final String openHours;
  final double cost; 
  final String? imageUrl; 
  final List<String> tags; 
  final DateTime scheduledDate; 
  final int orderIndex; 

  ActivityModel({
    required this.activityId,
    required this.tripId,
    required this.name, 
    required this.location,
    required this.openHours,
    required this.cost,
    this.imageUrl,
    this.tags = const [],
    required this.scheduledDate,
    required this.orderIndex,
  });

  factory ActivityModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      activityId: doc.id,
      tripId: data['tripId'] ?? '',
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      openHours: data['openHours'] ?? '',
      cost: (data['cost'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      orderIndex: data['orderIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tripId': tripId,
        'name': name,
        'location': location,
        'openHours': openHours,
        'cost': cost,
        'imageUrl': imageUrl,
        'tags': tags,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'orderIndex': orderIndex,
      };

  ActivityModel copyWith({int? orderIndex, String? imageUrl}) {
    return ActivityModel(
      activityId: activityId,
      tripId: tripId,
      name: name,
      location: location,
      openHours: openHours,
      cost: cost,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags,
      scheduledDate: scheduledDate,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}