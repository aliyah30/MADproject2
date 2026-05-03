import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../models/activity_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloud_functions_service.dart';

class OptimizerScreen extends StatefulWidget {
  final TripModel trip;
  const OptimizerScreen({super.key, required this.trip});

  @override
  State<OptimizerScreen> createState() => _OptimizerScreenState();
}

class _OptimizerScreenState extends State<OptimizerScreen> {
  final _firestoreService = FirestoreService();
  final _cfService = CloudFunctionsService();
  final _budgetCtrl = TextEditingController(text: '500');

  List<ActivityModel> _originalActivities = [];
  List<ActivityModel> _optimizedActivities = [];
  List<OptimizerResult> _moves = [];

  bool _isLoading = false;
  bool _hasOptimized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _runOptimizer() async {
    final activities = await _firestoreService
        .activitiesStream(widget.trip.tripId)
        .first;

    if (activities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add activities to your itinerary before optimizing.')));
      return;
    }

    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 500;

    setState(() {
      _isLoading = true;
      _originalActivities = List.from(activities);
    });

    try {
      final result = await _cfService.optimizeItinerary(
        tripId: widget.trip.tripId,
        activities: activities,
        budget: budget,
      );

      setState(() {
        _optimizedActivities = result.optimizedActivities;
        _moves = result.moves;
        _hasOptimized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Optimization failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOptimization() async {
    setState(() => _isSaving = true);
    try {
      // Save optimized order to Firestore
      await _firestoreService.updateActivityOrder(_optimizedActivities);
      await _firestoreService.saveOptimizedOrder(
        widget.trip.tripId,
        _optimizedActivities.map((a) => a.activityId).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Optimized order saved!'),
          backgroundColor: Color(0xFF00897B),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Itinerary Optimizer'),
        actions: _hasOptimized
            ? [
                TextButton(
                  onPressed: () => setState(() {
                    _hasOptimized = false;
                    _moves = [];
                  }),
                  child: const Text('Reset',
                      style: TextStyle(color: Colors.white)),
                ),
              ]
            : null,
      ),
      body: _hasOptimized
          ? _buildResultsView()
          : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_fix_high,
                    color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Smart Itinerary Optimizer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Our AI analyzes your activities by location, opening hours, and budget — then reorders them for the best possible day.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // How it works
          const Text('How It Works',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _HowItWorksTile(
            icon: Icons.location_searching,
            color: const Color(0xFF1976D2),
            title: 'Minimizes Travel Distance',
            subtitle:
                'Groups nearby activities together to reduce transit time',
          ),
          const SizedBox(height: 8),
          _HowItWorksTile(
            icon: Icons.access_time,
            color: const Color(0xFF00897B),
            title: 'Respects Opening Hours',
            subtitle:
                'Ensures you arrive when venues are actually open',
          ),
          const SizedBox(height: 8),
          _HowItWorksTile(
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFFF57C00),
            title: 'Stays Within Budget',
            subtitle:
                'Flags activities that push you over your daily budget',
          ),
          const SizedBox(height: 24),

          // Budget input
          const Text('Your Total Budget (USD)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _budgetCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '500',
              prefixIcon: Icon(Icons.attach_money),
              helperText: 'Cumulative budget across all activities',
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _isLoading ? null : _runOptimizer,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_fix_high),
            label: Text(
              _isLoading ? 'Analyzing...' : 'Optimize My Itinerary',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final movedCount = _moves.where((m) => m.originalIndex != m.newIndex).length;

    return Column(
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF7B1FA2).withOpacity(0.08),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF7B1FA2), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$movedCount ${movedCount == 1 ? 'activity' : 'activities'} reordered for a better experience',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Move reason cards
              if (_moves.any((m) => m.originalIndex != m.newIndex)) ...[
                const Text('Why Activities Were Moved',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._moves
                    .where((m) => m.originalIndex != m.newIndex)
                    .map((m) => _ReasonCard(move: m))
                    .toList(),
                const SizedBox(height: 24),
              ],

              // Optimized order list
              const Text('New Order',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._optimizedActivities.asMap().entries.map((entry) {
                final i = entry.key;
                final activity = entry.value;
                final moved = _moves.any((m) =>
                    m.activityId == activity.activityId &&
                    m.originalIndex != m.newIndex);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: moved
                          ? const Color(0xFF7B1FA2)
                          : const Color(0xFF00897B),
                      radius: 16,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(activity.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(activity.location,
                        style: const TextStyle(fontSize: 12)),
                    trailing: moved
                        ? const Chip(
                            label: Text('Moved',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                            backgroundColor: Color(0xFF7B1FA2),
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),

              // Accept / discard
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _acceptOptimization,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Accept & Save Order',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Discard Suggestions'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final OptimizerResult move;
  const _ReasonCard({required this.move});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color(0xFF7B1FA2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                color: Color(0xFF7B1FA2), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    move.activityName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Position ${move.originalIndex + 1} → ${move.newIndex + 1}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    move.reason,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _HowItWorksTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      );
}