import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_list.dart';
import '../state/app_state.dart';
import 'glitter_theme.dart';
import 'todo_tile.dart';

class ListPage extends ConsumerStatefulWidget {
  const ListPage({super.key, required this.list});

  final TodoList list;

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.list.items.isEmpty) {
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
    return SafeArea(
      top: false, // AppBar already handles the top inset.
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReorderableListView.builder(
            scrollController: _scrollController,
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            itemCount: widget.list.items.length,
            onReorder: (oldIndex, newIndex) =>
                notifier.reorderItem(widget.list.id, oldIndex, newIndex),
            itemBuilder: (ctx, i) {
              final item = widget.list.items[i];
              return TodoTile(
                key: ValueKey(item.id),
                listId: widget.list.id,
                item: item,
                index: i,
              );
            },
          ),
          // Half-way between the screen edge and the checkbox column
          // (TodoTile uses contentPadding: horizontal: 18, so checkbox
          // sits at ~18px from the left). 9px center, 3px wide thumb.
          Positioned(
            left: _ScrollIndicator.centerX - _ScrollIndicator.thumbWidth / 2,
            top: 0,
            bottom: 0,
            width: _ScrollIndicator.thumbWidth,
            child: _ScrollIndicator(
              controller: _scrollController,
              color: context.glitter.content,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollIndicator extends StatelessWidget {
  const _ScrollIndicator({
    required this.controller,
    required this.color,
  });

  static const centerX = 9.0;
  static const thumbWidth = 3.0;
  static const _minThumbHeight = 24.0;

  final ScrollController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasClients) return const SizedBox.shrink();
        final pos = controller.position;
        // `hasClients` only means a position is attached — its metrics
        // (maxScrollExtent / pixels / viewportDimension) are still null
        // until the first layout pass. Reading them in that window
        // throws "Null check operator used on a null value" via the
        // `!`-guarded getters, and the ErrorWidget renders into our
        // 3-px column as a tall stripe of red text.
        if (!pos.hasContentDimensions ||
            !pos.hasPixels ||
            !pos.hasViewportDimension) {
          return const SizedBox.shrink();
        }
        if (pos.maxScrollExtent <= 0) return const SizedBox.shrink();
        final visibleFrac = pos.viewportDimension /
            (pos.maxScrollExtent + pos.viewportDimension);
        final scrollFrac =
            (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final thumbH = (visibleFrac * h).clamp(_minThumbHeight, h);
            return Align(
              // Align(0, -1) puts child flush at the top, (0, +1) at the
              // bottom — so scrollFrac * 2 - 1 maps [0, 1] → [-1, +1].
              alignment: Alignment(0, scrollFrac * 2 - 1),
              child: SizedBox(
                width: thumbWidth,
                height: thumbH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(thumbWidth / 2),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
