import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/trip_model.dart';
import '../../models/activity_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class ActivitySearchScreen extends StatefulWidget {
  final TripModel trip;
  const ActivitySearchScreen({super.key, required this.trip});

  @override
  State<ActivitySearchScreen> createState() => _ActivitySearchScreenState();
}

class _ActivitySearchScreenState extends State<ActivitySearchScreen> {
  final _searchCtrl = TextEditingController();
  final _firestoreService = FirestoreService();

  // Local form state for adding a new activity manually
  bool _showAddForm = false;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime? _scheduledDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _hoursCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _addActivity() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a date for this activity')));
      return;
    }
    setState(() => _isSaving = true);

    try {
      // Count existing activities on this day to set orderIndex
      final activities = await _firestoreService
          .activitiesStream(widget.trip.tripId)
          .first;
      final sameDayCount = activities
          .where((a) =>
              DateFormat('yyyy-MM-dd').format(a.scheduledDate) ==
              DateFormat('yyyy-MM-dd').format(_scheduledDate!))
          .length;

      final newActivity = ActivityModel(
        activityId: '', // FirestoreService generates the ID
        tripId: widget.trip.tripId,
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        openHours: _hoursCtrl.text.trim(),
        cost: double.tryParse(_costCtrl.text.trim()) ?? 0,
        scheduledDate: _scheduledDate!,
        orderIndex: sameDayCount,
      );

      await _firestoreService.addActivity(newActivity);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity added!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add activity: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? widget.trip.startDate,
      firstDate: widget.trip.startDate,
      lastDate: widget.trip.endDate,
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showAddForm ? 'Add Activity' : 'Activity Search'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                setState(() => _showAddForm = !_showAddForm),
            icon: Icon(_showAddForm ? Icons.search : Icons.add,
                color: Colors.white),
            label: Text(_showAddForm ? 'Search' : 'Add Custom',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _showAddForm ? _buildAddForm() : _buildSearch(),
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search activities...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ActivityModel>>(
            // Show ALL activities across all trips matching search
            // (in a real app you'd have a dedicated activity database)
            stream:
                _firestoreService.activitiesStream(widget.trip.tripId),
            builder: (context, snapshot) {
              final allActivities = snapshot.data ?? [];
              final query = _searchCtrl.text.toLowerCase();
              final filtered = query.isEmpty
                  ? allActivities
                  : allActivities
                      .where((a) =>
                          a.name.toLowerCase().contains(query) ||
                          a.location.toLowerCase().contains(query))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No activities found'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showAddForm = true),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a custom activity'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  return ListTile(
                    leading: a.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(a.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF00897B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.place,
                                color: Color(0xFF00897B)),
                          ),
                    title: Text(a.name),
                    subtitle: Text(a.location),
                    trailing: Text('\$${a.cost.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddForm() {
    final fmt = DateFormat('MMM d, yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Activity Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  hintText: 'e.g. Snorkeling at Garrafon',
                  prefixIcon: Icon(Icons.place_outlined)),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 16),

            _label('Location'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  hintText: 'e.g. Isla Mujeres, Cancún',
                  prefixIcon: Icon(Icons.location_on_outlined)),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Location required'
                  : null,
            ),
            const SizedBox(height: 16),

            _label('Opening Hours'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _hoursCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  hintText: 'e.g. 9:00 AM – 5:00 PM',
                  prefixIcon: Icon(Icons.access_time_outlined)),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Hours required'
                  : null,
            ),
            const SizedBox(height: 16),

            _label('Estimated Cost (USD)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Cost required';
                if (double.tryParse(v.trim()) == null)
                  return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _label('Scheduled Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      _scheduledDate != null
                          ? fmt.format(_scheduledDate!)
                          : 'Select date (${fmt.format(widget.trip.startDate)} – ${fmt.format(widget.trip.endDate)})',
                      style: TextStyle(
                        color: _scheduledDate != null
                            ? Colors.black87
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isSaving ? null : _addActivity,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add to Itinerary',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );
}