import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../models/activity_model.dart';
import '../../services/firestore_service.dart';
import 'activity_search_screen.dart';

class ItineraryBuilderScreen extends StatelessWidget {
  final TripModel trip;
  const ItineraryBuilderScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Activity',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ActivitySearchScreen(trip: trip)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ActivityModel>>(
        stream: firestoreService.activitiesStream(trip.tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return _EmptyItinerary(
              onAddActivity: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ActivitySearchScreen(trip: trip)),
              ),
            );
          }

          // Group activities by scheduled date
          final Map<String, List<ActivityModel>> byDay = {};
          final dayFmt = DateFormat('yyyy-MM-dd');
          for (final a in activities) {
            final key = dayFmt.format(a.scheduledDate);
            byDay.putIfAbsent(key, () => []).add(a);
          }

          final sortedDays = byDay.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: sortedDays.length,
            itemBuilder: (context, dayIdx) {
              final dayKey = sortedDays[dayIdx];
              final dayActivities = byDay[dayKey]!;
              final date = DateTime.parse(dayKey);
              final dayLabel = DateFormat('EEEE, MMM d').format(date);
              final dayNum = date.difference(trip.startDate).inDays + 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dayLabel,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Reorderable activity list for this day
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayActivities.length,
                    onReorder: (oldIdx, newIdx) async {
                      if (newIdx > oldIdx) newIdx--;
                      final reordered = List<ActivityModel>.from(dayActivities);
                      final item = reordered.removeAt(oldIdx);
                      reordered.insert(newIdx, item);

                      // Re-index the reordered list
                      final updated = reordered
                          .asMap()
                          .entries
                          .map((e) => e.value.copyWith(orderIndex: e.key))
                          .toList();

                      await firestoreService.updateActivityOrder(updated);
                    },
                    itemBuilder: (context, i) {
                      final activity = dayActivities[i];
                      return ActivityCard(
                        key: ValueKey(activity.activityId),
                        activity: activity,
                        onDelete: () async {
                          final confirm = await _confirmDelete(context);
                          if (confirm == true) {
                            await firestoreService
                                .deleteActivity(activity.activityId);
                          }
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ActivitySearchScreen(trip: trip)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Activity?'),
        content: const Text(
            'This will remove the activity for all group members.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onDelete;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: activity.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  activity.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderIcon(),
                ),
              )
            : _PlaceholderIcon(),
        title: Text(
          activity.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  activity.location,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time_outlined,
                  size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(activity.openHours,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.attach_money,
                  size: 12, color: Colors.grey),
              Text('\$${activity.cost.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF00897B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.place, color: Color(0xFF00897B)),
      );
}

class _EmptyItinerary extends StatelessWidget {
  final VoidCallback onAddActivity;
  const _EmptyItinerary({required this.onAddActivity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No activities yet',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Search and add activities to build your day-by-day itinerary.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddActivity,
              icon: const Icon(Icons.add),
              label: const Text('Add First Activity'),
            ),
          ],
        ),
      ),
    );
  }
}