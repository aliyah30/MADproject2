import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';

class CreateTripScreen extends StatefulWidget {
  final String hostUid;
  const CreateTripScreen({super.key, required this.hostUid});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _firestoreService = FirestoreService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  final _fmt = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestoreService.createTrip(
        name: _nameCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        hostUid: widget.hostUid,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create trip: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Details',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                _label('Trip Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cancún Spring Break',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Trip name is required' : null,
                ),
                const SizedBox(height: 16),

                _label('Destination'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _destinationCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cancún, Mexico',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Destination is required'
                      : null,
                ),
                const SizedBox(height: 24),

                _label('Travel Dates'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Start Date',
                        value: _startDate != null
                            ? _fmt.format(_startDate!)
                            : null,
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward,
                        color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateButton(
                        label: 'End Date',
                        value: _endDate != null
                            ? _fmt.format(_endDate!)
                            : null,
                        onTap: _pickEndDate,
                      ),
                    ),
                  ],
                ),

                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${_endDate!.difference(_startDate!).inDays} day trip',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _createTrip,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Trip',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
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

class _DateButton extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(
              value ?? 'Select',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value != null
                    ? Colors.black87
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}