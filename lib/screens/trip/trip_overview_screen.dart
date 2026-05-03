import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import '../itinerary/itinerary_builder_screen.dart';
import '../packing/packing_list_screen.dart';
import '../checklist/checklist_screen.dart';
import '../optimizer/optimizer_screen.dart';

class TripOverviewScreen extends StatelessWidget {
  final TripModel trip;
  const TripOverviewScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tripDays =
        trip.endDate.difference(trip.startDate).inDays + 1;

    return StreamBuilder<TripModel?>(
      stream: FirestoreService().tripStream(trip.tripId),
      builder: (context, snapshot) {
        final currentTrip = snapshot.data ?? trip;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Collapsible hero header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    currentTrip.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                      ),
                      image: currentTrip.coverImageUrl != null
                          ? DecorationImage(
                              image:
                                  NetworkImage(currentTrip.coverImageUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.35),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 56),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                currentTrip.destination,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick stats row
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.calendar_today,
                            label: '$tripDays days',
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.people,
                            label:
                                '${currentTrip.memberUids.length} travelers',
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.date_range,
                            label: fmt.format(currentTrip.startDate),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Date range
                      _SectionHeader('Trip Dates'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            _DateBlock(
                                label: 'Departs',
                                date: fmt.format(currentTrip.startDate)),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey.shade300,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            _DateBlock(
                                label: 'Returns',
                                date: fmt.format(currentTrip.endDate)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation tiles
                      _SectionHeader('Plan Your Trip'),
                      const SizedBox(height: 12),
                      _NavTile(
                        icon: Icons.map,
                        color: const Color(0xFF00897B),
                        title: 'Itinerary Builder',
                        subtitle: 'Schedule activities day by day',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItineraryBuilderScreen(
                                trip: currentTrip),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        icon: Icons.auto_fix_high,
                        color: const Color(0xFF7B1FA2),
                        title: 'AI Optimizer',
                        subtitle:
                            'Reorder activities by distance & hours',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OptimizerScreen(trip: currentTrip),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        icon: Icons.backpack,
                        color: const Color(0xFF1976D2),
                        title: 'Packing List',
                        subtitle: 'Shared checklist for the group',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PackingListScreen(
                                tripId: currentTrip.tripId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        icon: Icons.checklist,
                        color: const Color(0xFFF57C00),
                        title: 'Trip Checklist',
                        subtitle: 'Visas, bookings, essentials',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChecklistScreen(
                                tripId: currentTrip.tripId),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00897B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF00897B)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00897B),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _DateBlock extends StatelessWidget {
  final String label;
  final String date;
  const _DateBlock({required this.label, required this.date});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(date,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
}