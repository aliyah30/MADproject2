import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/trip_model.dart';
import 'trip_overview_screen.dart';
import 'create_trip_screen.dart';

class TripsHomeScreen extends StatelessWidget {
  const TripsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}, // future: search trips
          ),
        ],
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: firestoreService.tripsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error loading trips: ${snapshot.error}'),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return _EmptyTripsView(
              onCreateTrip: () => _openCreateTrip(context, uid),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _TripCard(trip: trips[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateTrip(context, uid),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _openCreateTrip(BuildContext context, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateTripScreen(hostUid: uid)),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final daysLeft = trip.endDate.difference(DateTime.now()).inDays;
    final isUpcoming = daysLeft >= 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TripOverviewScreen(trip: trip)),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Cover image or gradient placeholder
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00897B),
                    const Color(0xFF26A69A),
                  ],
                ),
                image: trip.coverImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(trip.coverImageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isUpcoming
                            ? '$daysLeft days away'
                            : 'Past trip',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    // Trip name
                    Text(
                      trip.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          trip.destination,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${fmt.format(trip.startDate)} – ${fmt.format(trip.endDate)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Member count chip
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people,
                        size: 14, color: Color(0xFF00897B)),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.memberUids.length}',
                      style: const TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTripsView extends StatelessWidget {
  final VoidCallback onCreateTrip;
  const _EmptyTripsView({required this.onCreateTrip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No trips yet',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first trip and invite your travel group to plan together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.add),
              label: const Text('Create a Trip'),
            ),
          ],
        ),
      ),
    );
  }
}