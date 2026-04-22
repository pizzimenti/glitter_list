import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_list.dart';
import '../state/app_state.dart';
import 'todo_tile.dart';

class ListPage extends ConsumerWidget {
  const ListPage({super.key, required this.list});

  final TodoList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Empty list.\nTap + to add an item.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final notifier = ref.read(appStateProvider.notifier);
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: list.items.length,
      onReorder: (oldIndex, newIndex) =>
          notifier.reorderItem(list.id, oldIndex, newIndex),
      itemBuilder: (ctx, i) {
        final item = list.items[i];
        return TodoTile(
          key: ValueKey(item.id),
          listId: list.id,
          item: item,
          index: i,
        );
      },
    );
  }
}
