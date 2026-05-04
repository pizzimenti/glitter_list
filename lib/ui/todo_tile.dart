import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_item.dart';
import '../state/app_state.dart';
import 'check_animation.dart';
import 'glitter_outline.dart';
import 'glitter_theme.dart';
import 'text_prompt_dialog.dart';

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
  late final AnimationController _checkCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      value: widget.item.done ? 1.0 : 0.0,
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didUpdateWidget(TodoTile old) {
    super.didUpdateWidget(old);
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
    _checkCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  /// Open the edit dialog prepopulated with the current text. The
  /// previous flow flipped the title to a TextField in place, but the
  /// inline editor sat behind the squiggle / strip layers and clipped
  /// most of the text being edited. A modal AlertDialog gives the
  /// user the full glyph string to work with.
  Future<void> _promptEdit() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Edit item',
        confirmLabel: 'Save',
        initialValue: widget.item.text,
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == widget.item.text) return;
    await ref
        .read(appStateProvider.notifier)
        .editItemText(widget.listId, widget.item.id, trimmed);
  }

  Future<void> _showItemMenu() async {
    final isGlittered = widget.item.glittered;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            // Glitter / Un-Glitter sits at the top — it's the
            // signature gesture of this app and the most common
            // long-press intent. Edit + Delete live below.
            ListTile(
              leading: const Text('🪄', style: TextStyle(fontSize: 24)),
              title: Text(isGlittered ? 'Un-Glitter Item' : 'Glitter Item'),
              onTap: () => Navigator.pop(ctx, 'glitter'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
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
        await _promptEdit();
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

    // Multi-line rows get extra vertical contentPadding so the
    // squiggle outline on glittered items (extends ≈6 px past the
    // text bounds via the +2 px lineRect pad and ≈4 px outward wave
    // peak) doesn't overlap the squiggle on the row below or above.
    // Keying the padding on wrap (not on `glittered`) means toggling
    // glitter doesn't reflow the list — items stay put.
    //
    // Wrap detection: lay out a TextPainter once per build at an
    // approximate title-slot width. ListTile's title is constrained
    // by `parentMaxWidth - contentPadding.horizontal*2 - leading slot
    // - leading↔title gap - trailing slot - title↔trailing gap`. With
    // our 64-px leading slot and reorder drag handle, the inset is
    // ≈186 px. The TextPainter is small and disposed immediately.
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final titleMaxWidth = math.max(0.0, mediaWidth - 186);
    final tp = TextPainter(
      text: TextSpan(text: widget.item.text, style: baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: titleMaxWidth);
    final wraps = tp.computeLineMetrics().length > 1;
    tp.dispose();
    final verticalPadding = wraps ? 8.0 : 2.0;
    return ListTile(
      key: widget.key,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 2,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 22,
        vertical: verticalPadding,
      ),
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
      // Layering for glittered + (optionally) done items:
      // RainbowStrikethrough renders, in order, the per-line frosted
      // slab → the glitter squiggle (as the between-layer) → the
      // glyphs → the rainbow strikethrough painter on top. Composing
      // this through one widget keeps the squiggle below the text
      // but above the slab; rendering the squiggle as a sibling of
      // RainbowStrikethrough would let the slab paint over it.
      //
      // The squiggle's contour is built against the OUTER
      // TextPainter's line metrics (passed in via the builder) —
      // letting GlitterOutline lay out its own TextPainter would
      // re-break under a tighter inner maxWidth and the squiggle
      // would trace a different polygon than the slab strips it
      // sits between.
      //
      // Horizontal outset only on the slab — a vertical outset would
      // make adjacent lines' strips overlap on multi-line wraps.
      title: Align(
        alignment: AlignmentDirectional.centerStart,
        child: RainbowStrikethrough(
          text: widget.item.text,
          baseStyle: baseStyle,
          mutedColor: mutedColor,
          progress: _checkCtrl,
          backdropOutset: widget.item.glittered
              ? const EdgeInsets.symmetric(horizontal: 10)
              : EdgeInsets.zero,
          betweenLayerBuilder: (lines, size) => GlitterOutline(
            text: widget.item.text,
            style: baseStyle,
            glittered: widget.item.glittered,
            seed: widget.item.id.hashCode,
            precomputedLines: lines,
            precomputedSize: size,
          ),
        ),
      ),
      onTap: () => _shimmerCtrl.forward(from: 0),
      onLongPress: _showItemMenu,
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
