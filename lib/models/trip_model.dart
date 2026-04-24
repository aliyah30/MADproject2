import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String tripId;
  final String name;
  final String destination;
  final List<String> memberUids;
  final String hostUid;
  final DateTime startDate;
  final DateTime endDate;
  final String? coverImageUrl;
  final List<String> optimizedOrder;
  final DateTime createdAt;

  TripModel({
    required this.tripId,
    required this.name,
    required this.destination,
    required this.memberUids,
    required this.hostUid,
    required this.startDate,
    required this.endDate,
    this.coverImageUrl,
    this.optimizedOrder = const [],
    required this.createdAt,
  });


  factory TripModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripModel(
      tripId: doc.id,
      name: data['name'] ?? '',
      destination: data['destination'] ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? []),
      hostUid: data['hostUid'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      coverImageUrl: data['coverImageUrl'],
      optimizedOrder: List<String>.from(data['optimizedOrder'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }


  Map<String, dynamic> toMap() => {
        'name': name,
        'destination': destination,
        'memberUids': memberUids,
        'hostUid': hostUid,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'coverImageUrl': coverImageUrl,
        'optimizedOrder': optimizedOrder,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}