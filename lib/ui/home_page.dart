import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'add_list_sheet.dart';
import 'glitter_theme.dart';
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

    final titleText = currentList?.name ?? 'Glitter List';
    final titleStyle = TextStyle(
      color: context.glitter.content,
      fontSize: context.glitter.titleFontSize,
      fontFamily: 'Sniglet',
      height: 1.2,
    );
    // Rough horizontal budget: screen width minus AppBar padding, the
    // hamburger action, page dots, and Row spacing. Errs on the tight side
    // so wrapping triggers before ellipsis would.
    final screenWidth = MediaQuery.of(context).size.width;
    final titleMaxWidth =
        (screenWidth - 16 - 48 - (state.lists.length > 1 ? 40 : 0) - 16)
            .clamp(100.0, double.infinity);
    final measured = TextPainter(
      text: TextSpan(text: titleText, style: titleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: titleMaxWidth);
    final measuredHeight = measured.height;
    measured.dispose();
    final toolbarHeight = math.max(kToolbarHeight, measuredHeight + 24);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                titleText,
                style: titleStyle,
                maxLines: 3,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _PageDots(count: state.lists.length, index: state.currentListIndex),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'new':
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AddListSheet(),
                  );
                case 'rename':
                  if (currentList != null) {
                    await _promptRename(currentList.id, currentList.name);
                  }
                case 'clear':
                  if (currentList != null) {
                    final count =
                        currentList.items.where((i) => i.done).length;
                    await _confirmClearCompleted(currentList.id, count);
                  }
                case 'delete':
                  if (currentList != null) {
                    await _confirmDeleteList(currentList.id, currentList.name);
                  }
              }
            },
            itemBuilder: (_) => [
              _MenuItem(
                value: 'new',
                icon: Icons.playlist_add,
                label: 'New List',
              ),
              if (currentList != null)
                _MenuItem(
                  value: 'rename',
                  icon: Icons.drive_file_rename_outline,
                  label: 'Rename List',
                ),
              if (currentList != null &&
                  currentList.items.any((i) => i.done))
                _MenuItem(
                  value: 'clear',
                  icon: Icons.cleaning_services_outlined,
                  label: 'Clear Completed',
                ),
              if (currentList != null)
                _MenuItem(
                  value: 'delete',
                  icon: Icons.delete_outline,
                  label: 'Delete List',
                ),
            ],
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
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: 'Rename list',
        confirmLabel: 'Save',
        initialValue: currentName,
      ),
    );
    if (!mounted) return;
    final trimmed = result?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      await ref.read(appStateProvider.notifier).renameList(listId, trimmed);
    }
  }

  Future<void> _confirmClearCompleted(String listId, int count) async {
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear $count completed item${count == 1 ? '' : 's'}?',
        ),
        content: const Text('They will be removed from this list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await ref.read(appStateProvider.notifier).clearCompleted(listId);
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
    if (!mounted) return;
    if (confirmed == true) {
      await ref.read(appStateProvider.notifier).deleteList(listId);
    }
  }

  Future<void> _promptAddItem(String listId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: 'New item',
        confirmLabel: 'Add',
      ),
    );
    if (!mounted) return;
    final trimmed = result?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      await ref.read(appStateProvider.notifier).addItem(listId, trimmed);
    }
  }
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String? initialValue;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _MenuItem extends PopupMenuItem<String> {
  // Not const: Dart rejects `invalid_constant` because the super()
  // initializer constructs a new `_MenuItemRow(icon: icon, label: label)`
  // whose arguments are this constructor's parameters — those aren't
  // treated as const-evaluable in a sub-expression inside super(), even
  // when the outer invocation (`const _MenuItem(...)`) passes compile-
  // time constants. Verified with explicit `const _MenuItemRow(...)`
  // (column 43 error) and without (column 18 error). Re-flagged by
  // CodeRabbit across two rounds; the suggestion is based on a rule
  // relaxation that doesn't exist in current Dart semantics.
  _MenuItem({
    required String super.value,
    required IconData icon,
    required String label,
  }) : super(
          height: 72,
          child: _MenuItemRow(icon: icon, label: label),
        );
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(fontSize: 20)),
      ],
    );
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
