import 'package:flutter/material.dart';

class ChecklistTabScreen extends StatelessWidget {
  const ChecklistTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checklist_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('Open a trip to view checklist',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Go to the Trips tab and tap a trip to manage its checklist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}