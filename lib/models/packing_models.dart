import 'package:cloud_firestore/cloud_firestore.dart';

//Packing List Item 
class PackingItem {
  final String itemId;
  final String name;
  final String? assignedTo; // uid of member responsible
  final bool checked;

  PackingItem({
    required this.itemId,
    required this.name,
    this.assignedTo,
    this.checked = false,
  });

   factory PackingItem.fromMap(Map<String, dynamic> data) {
    return PackingItem(
      itemId: data['itemId'] ?? '',
      name: data['name'] ?? '',
      assignedTo: data['assignedTo'],
      checked: data['checked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'name': name,
        'assignedTo': assignedTo,
        'checked': checked,
      };

PackingItem copyWith({bool? checked, String? assignedTo}) {
    return PackingItem(
      itemId: itemId,
      name: name,
      assignedTo: assignedTo ?? this.assignedTo,
      checked: checked ?? this.checked,
    );
  }
}

class PackingListModel {
  final String tripId;
  final List<PackingItem> items;

  PackingListModel({required this.tripId, required this.items});

  factory PackingListModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return PackingListModel(
      tripId: doc.id,
      items: rawItems
          .map((i) => PackingItem.fromMap(i as Map<String, dynamic>))
          .toList(),
           );
  }

  Map<String, dynamic> toMap() => {
        'items': items.map((i) => i.toMap()).toList(),
      };
}

class ChecklistTask {
  final String taskId;
  final String title;
  final bool completed;
  final DateTime? dueDate;

  ChecklistTask({
    required this.taskId,
    required this.title,
    this.completed = false,
    this.dueDate,
  });

  factory ChecklistTask.fromMap(Map<String, dynamic> data) {
    return ChecklistTask(
      taskId: data['taskId'] ?? '',
      title: data['title'] ?? '',
      completed: data['completed'] ?? false,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
    );
  }
  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'title': title,
        'completed': completed,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      };

  ChecklistTask copyWith({bool? completed}) {
    return ChecklistTask(
      taskId: taskId,
      title: title,
      completed: completed ?? this.completed,
      dueDate: dueDate,
    );
  }
}

class ChecklistModel {
  final String tripId;
  final List<ChecklistTask> tasks;

  ChecklistModel({required this.tripId, required this.tasks});

  factory ChecklistModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawTasks = data['tasks'] as List<dynamic>? ?? [];
    return ChecklistModel(
      tripId: doc.id,
      tasks: rawTasks
          .map((t) => ChecklistTask.fromMap(t as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tasks': tasks.map((t) => t.toMap()).toList(),
      };
}
