import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../state/app_state.dart';
import 'check_animation.dart';
import 'glitter_outline.dart';
import 'glitter_theme.dart';

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

class _TodoTileState extends ConsumerState<TodoTile>
    with TickerProviderStateMixin {
  bool _editing = false;
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _checkCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      value: widget.item.done ? 1.0 : 0.0,
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(TodoTile old) {
    super.didUpdateWidget(old);
    if (!_editing && widget.item.text != _controller.text) {
      _controller.text = widget.item.text;
    }
    if (old.item.done != widget.item.done) {
      if (widget.item.done) {
        _checkCtrl.forward(from: 0);
      } else {
        _checkCtrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _checkCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
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
    final isGlittered = widget.item.glittered;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Text('🪄', style: TextStyle(fontSize: 24)),
              title: Text(isGlittered ? 'Un-Glitter Item' : 'Glitter Item'),
              onTap: () => Navigator.pop(ctx, 'glitter'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        _startEdit();
      case 'glitter':
        await ref
            .read(appStateProvider.notifier)
            .toggleGlitter(widget.listId, widget.item.id);
      case 'delete':
        await ref
            .read(appStateProvider.notifier)
            .deleteItem(widget.listId, widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appStateProvider.notifier);
    final glitter = context.glitter;
    final scheme = Theme.of(context).colorScheme;
    final mutedColor = scheme.onSurface.withValues(alpha: 0.5);
    final baseStyle = TextStyle(
      color: glitter.content,
      fontSize: glitter.bodyFontSize,
      height: 1.0,
    );

    return ListTile(
      key: widget.key,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
      leading: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Sparkles emanate from the center of this slot.
            Positioned.fill(
              child: SparkleBurst(
                progress: _checkCtrl,
                color: kCheckGlow,
              ),
            ),
            Positioned.fill(
              child: SparkleBurst(
                progress: _shimmerCtrl,
                color: kCheckGlow,
              ),
            ),
            GlowingCheckbox(
              value: widget.item.done,
              glowColor: kCheckGlow,
              borderColor: glitter.content,
              progress: _checkCtrl,
              onChanged: (_) =>
                  notifier.toggleItem(widget.listId, widget.item.id),
            ),
          ],
        ),
      ),
      // Align hands a loose constraint to the child so the BackdropFilter
      // Static rendering goes through RainbowStrikethrough, which hosts
      // its own per-line PerLineBackdropBlur internally — strips sample
      // a pre-baked, pre-blurred bg image (no live BackdropFilter, no
      // engine race during scroll). Inline-edit drops the blur entirely
      // for now: text wraps live as the user types, per-line splitting
      // doesn't work mid-typing, and a blur for the brief editing window
      // isn't worth the complexity.
      title: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _editing
            ? TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: baseStyle,
                cursorColor: glitter.content,
                onSubmitted: (_) => _commit(),
                onTapOutside: (_) => _commit(),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              )
            : Stack(
                children: [
                  GlitterOutline(
                    text: widget.item.text,
                    style: baseStyle,
                    glittered: widget.item.glittered,
                    seed: widget.item.id.hashCode,
                  ),
                  RainbowStrikethrough(
                    text: widget.item.text,
                    baseStyle: baseStyle,
                    mutedColor: mutedColor,
                    progress: _checkCtrl,
                  ),
                ],
              ),
      ),
      onTap: _editing ? null : () => _shimmerCtrl.forward(from: 0),
      onLongPress: _editing ? null : _showItemMenu,
      trailing: ReorderableDragStartListener(
        index: widget.index,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(Icons.drag_handle),
        ),
      ),
    );
  }
}
