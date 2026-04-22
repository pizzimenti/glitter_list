import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../state/app_state.dart';

class TodoTile extends ConsumerStatefulWidget {
  const TodoTile({
    super.key,
    required this.listId,
    required this.item,
    required this.index,
  });

  final String listId;
  final TodoItem item;
  final int index;

  @override
  ConsumerState<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends ConsumerState<TodoTile> {
  bool _editing = false;
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(TodoTile old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() => _editing = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _commit() {
    if (!_editing) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = widget.item.text;
    } else if (text != widget.item.text) {
      ref
          .read(appStateProvider.notifier)
          .editItemText(widget.listId, widget.item.id, text);
    }
    setState(() => _editing = false);
  }

  Future<void> _showItemMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete' && mounted) {
      await ref
          .read(appStateProvider.notifier)
          .deleteItem(widget.listId, widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appStateProvider.notifier);
    final textStyle = widget.item.done
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          )
        : null;

    return ListTile(
      key: widget.key,
      leading: Checkbox(
        value: widget.item.done,
        onChanged: (_) =>
            notifier.toggleItem(widget.listId, widget.item.id),
      ),
      title: _editing
          ? TextField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
            )
          : Text(widget.item.text, style: textStyle),
      onTap: _editing ? null : _startEdit,
      onLongPress: _editing ? null : _showItemMenu,
      trailing: ReorderableDragStartListener(
        index: widget.index,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Icon(Icons.drag_handle),
        ),
      ),
    );
  }
}
