import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'add_list_sheet.dart';
import 'list_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: ref.read(appStateProvider).currentListIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (prev, next) {
      if (!_controller.hasClients) return;
      final page = _controller.page?.round();
      if (page != next.currentListIndex &&
          next.currentListIndex < next.lists.length) {
        _controller.animateToPage(
          next.currentListIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final currentList =
        state.lists.isEmpty ? null : state.lists[state.currentListIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                currentList?.name ?? 'Glitter List',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _PageDots(count: state.lists.length, index: state.currentListIndex),
          ],
        ),
        actions: [
          if (currentList != null)
            PopupMenuButton<String>(
              onSelected: (action) async {
                switch (action) {
                  case 'rename':
                    await _promptRename(currentList.id, currentList.name);
                  case 'delete':
                    await _confirmDeleteList(currentList.id, currentList.name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename list')),
                PopupMenuItem(value: 'delete', child: Text('Delete list')),
              ],
            ),
          IconButton(
            tooltip: 'Add list',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const AddListSheet(),
            ),
          ),
        ],
      ),
      body: state.lists.isEmpty
          ? const Center(child: Text('No lists'))
          : PageView.builder(
              controller: _controller,
              itemCount: state.lists.length,
              onPageChanged: notifier.switchList,
              itemBuilder: (_, i) => ListPage(list: state.lists[i]),
            ),
      floatingActionButton: currentList == null
          ? null
          : FloatingActionButton(
              onPressed: () => _promptAddItem(currentList.id),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _promptRename(String listId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      await ref.read(appStateProvider.notifier).renameList(listId, trimmed);
    }
  }

  Future<void> _confirmDeleteList(String listId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Items in this list will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appStateProvider.notifier).deleteList(listId);
    }
  }

  Future<void> _promptAddItem(String listId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      await ref.read(appStateProvider.notifier).addItem(listId, trimmed);
    }
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 10 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
