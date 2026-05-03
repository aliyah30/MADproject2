import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/packing_models.dart';

class PackingListScreen extends StatelessWidget {
  final String tripId;
  const PackingListScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packing List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItemDialog(context, firestoreService),
          ),
        ],
      ),
      body: StreamBuilder<PackingListModel?>(
        stream: firestoreService.packingListStream(tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final model = snapshot.data;
          final items = model?.items ?? [];

          if (items.isEmpty) {
            return _EmptyPackingView(
              onAdd: () =>
                  _showAddItemDialog(context, firestoreService),
            );
          }

          final unchecked =
              items.where((i) => !i.checked).toList();
          final checked = items.where((i) => i.checked).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _PackingProgress(items: items),
              ),

              // Unpacked items
              if (unchecked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'To Pack (${unchecked.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey),
                  ),
                ),
                ...unchecked.map((item) => _PackingItemTile(
                      item: item,
                      currentUid: uid,
                      onToggle: (checked) =>
                          firestoreService.togglePackingItem(
                            tripId,
                            item.itemId,
                            checked,
                            assignedTo: checked ? uid : null,
                          ),
                      onDelete: () => firestoreService
                          .removePackingItem(tripId, item),
                    )),
              ],

              // Packed items
              if (checked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Packed (${checked.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF00897B)),
                  ),
                ),
                ...checked.map((item) => _PackingItemTile(
                      item: item,
                      currentUid: uid,
                      onToggle: (checked) =>
                          firestoreService.togglePackingItem(
                            tripId,
                            item.itemId,
                            checked,
                          ),
                      onDelete: () => firestoreService
                          .removePackingItem(tripId, item),
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddItemDialog(context, firestoreService),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddItemDialog(
      BuildContext context, FirestoreService firestoreService) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Packing Item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Sunscreen'),
          onSubmitted: (_) async {
            if (ctrl.text.trim().isNotEmpty) {
              await firestoreService.addPackingItem(
                  tripId, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await firestoreService.addPackingItem(
                    tripId, ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PackingProgress extends StatelessWidget {
  final List<PackingItem> items;
  const _PackingProgress({required this.items});

  @override
  Widget build(BuildContext context) {
    final packedCount = items.where((i) => i.checked).length;
    final progress =
        items.isEmpty ? 0.0 : packedCount / items.length;

    return Column(
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
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF00897B)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$packedCount / ${items.length}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          progress == 1.0
              ? 'All packed! Ready to go! 🎉'
              : '${(progress * 100).toInt()}% packed',
          style: TextStyle(
              fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _PackingItemTile extends StatelessWidget {
  final PackingItem item;
  final String currentUid;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;

  const _PackingItemTile({
    required this.item,
    required this.currentUid,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMyItem = item.assignedTo == currentUid;

    return Dismissible(
      key: Key(item.itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove item?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                  child: const Text('Remove')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Checkbox(
          value: item.checked,
          activeColor: const Color(0xFF00897B),
          onChanged: (v) => onToggle(v ?? false),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration:
                item.checked ? TextDecoration.lineThrough : null,
            color: item.checked ? Colors.grey : null,
          ),
        ),
        subtitle: item.assignedTo != null
            ? Text(
                isMyItem ? 'Packed by you' : 'Packed by a teammate',
                style: TextStyle(
                    fontSize: 11,
                    color: item.checked
                        ? const Color(0xFF00897B)
                        : Colors.grey.shade500),
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

class _EmptyPackingView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPackingView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.backpack_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('Packing list is empty',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Add items and assign them to group members.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add First Item'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2)),
              ),
            ],
          ),
        ),
      );
}