import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/packing_models.dart';

class ChecklistScreen extends StatelessWidget {
  final String tripId;
  const ChecklistScreen({super.key, required this.tripId});

  // Pre-seeded suggestions for common trip tasks
  static const _suggestions = [
    'Book flights',
    'Book hotel / accommodation',
    'Apply for visa',
    'Get travel insurance',
    'Exchange currency',
    'Download offline maps',
    'Notify bank of travel dates',
    'Pack medications',
    'Print boarding passes',
    'Confirm airport transfer',
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () =>
                _showAddTaskDialog(context, firestoreService),
          ),
        ],
      ),
      body: StreamBuilder<ChecklistModel?>(
        stream: firestoreService.checklistStream(tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final model = snapshot.data;
          final tasks = model?.tasks ?? [];

          if (tasks.isEmpty) {
            return _EmptyChecklistView(
              suggestions: _suggestions,
              onAddSuggestion: (title) async {
                await firestoreService.addChecklistTask(
                    tripId, title, null);
              },
              onAdd: () =>
                  _showAddTaskDialog(context, firestoreService),
            );
          }

          final incomplete =
              tasks.where((t) => !t.completed).toList();
          final complete = tasks.where((t) => t.completed).toList();
          final progress =
              tasks.isEmpty ? 0.0 : complete.length / tasks.length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  const AlwaysStoppedAnimation(
                                      Color(0xFFF57C00)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${complete.length} / ${tasks.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress == 1.0
                          ? 'All done! Trip is ready! ✈️'
                          : '${(progress * 100).toInt()}% complete',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              if (incomplete.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('To Do (${incomplete.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey)),
                ),
                ...incomplete.map((task) => _ChecklistTile(
                      task: task,
                      onToggle: (done) =>
                          firestoreService.toggleChecklistTask(
                              tripId, task.taskId, done),
                      onDelete: () =>
                          firestoreService.removeChecklistTask(
                              tripId, task),
                    )),
              ],

              if (complete.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Done (${complete.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFF57C00))),
                ),
                ...complete.map((task) => _ChecklistTile(
                      task: task,
                      onToggle: (done) =>
                          firestoreService.toggleChecklistTask(
                              tripId, task.taskId, done),
                      onDelete: () =>
                          firestoreService.removeChecklistTask(
                              tripId, task),
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddTaskDialog(context, firestoreService),
        backgroundColor: const Color(0xFFF57C00),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTaskDialog(
      BuildContext context, FirestoreService firestoreService) {
    final titleCtrl = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Task',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Book hotel',
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Optional due date
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? 'Due ${DateFormat('MMM d, yyyy').format(selectedDate!)}'
                                : 'Add due date (optional)',
                            style: TextStyle(
                                color: selectedDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade500),
                          ),
                          if (selectedDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setModalState(
                                  () => selectedDate = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        await firestoreService.addChecklistTask(
                          tripId,
                          titleCtrl.text.trim(),
                          selectedDate,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF57C00),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add Task',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ChecklistTask task;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;

  const _ChecklistTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.dueDate != null &&
        !task.completed &&
        task.dueDate!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(task.taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          activeColor: const Color(0xFFF57C00),
          onChanged: (v) => onToggle(v ?? false),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text(
                'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue
                      ? Colors.red
                      : Colors.grey.shade500,
                  fontWeight: isOverdue
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: Colors.grey),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyChecklistView extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onAddSuggestion;
  final VoidCallback onAdd;

  const _EmptyChecklistView({
    required this.suggestions,
    required this.onAddSuggestion,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.checklist_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Checklist is empty',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  'Add tasks to track visa requirements, bookings, and essentials.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF57C00)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Suggested Tasks',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (s) => ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: Text(s),
                    onPressed: () => onAddSuggestion(s),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}