import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_list.dart';
import '../state/app_state.dart';
import 'glitter_theme.dart';
import 'per_line_backdrop_blur.dart';
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
      final glitter = context.glitter;
      final heroHeight = MediaQuery.sizeOf(context).height / 3;
      final emptyStyle = TextStyle(
        color: glitter.content,
        fontSize: glitter.bodyFontSize * 1.4,
        height: 1.2,
      );
      return SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/caticorn.png',
                  height: heroHeight,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PerLineBackdropBlur(
                    text: 'Empty list. Tap + to add an item.',
                    style: emptyStyle,
                    softWrap: false,
                  ),
                ),
              ],
            ),
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
            // ReorderableListView's default proxyDecorator wraps the
            // lifted tile in Material so ListTile's ink/ripple has an
            // ancestor; passing a custom decorator replaces the default,
            // so we have to re-establish Material here ourselves —
            // otherwise dragging throws "No Material widget found"
            // because the OverlayEntry that hosts the proxy sits above
            // every Scaffold/Material in the tree. Parallax state, on
            // the other hand, is now reachable from inside the overlay
            // because BgParallaxHost (and BgParallaxScope) sit above
            // MaterialApp, so no re-publish is needed here.
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, c) {
                  final t = Curves.easeInOut.transform(animation.value);
                  return Material(
                    elevation: 6 * t,
                    color: Colors.transparent,
                    shadowColor: Colors.transparent,
                    child: c,
                  );
                },
                child: child,
              );
            },
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
          // (TodoTile uses contentPadding: horizontal: 22, so checkbox
          // sits at ~22 px from the left). 9 px center; the column is
          // wide enough to host the thumb plus the two flanking rails.
          Positioned(
            left: _ScrollIndicator.centerX - _ScrollIndicator.totalWidth / 2,
            top: 0,
            bottom: 0,
            width: _ScrollIndicator.totalWidth,
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
  static const railWidth = 1.0;
  static const _railGap = 3.0;
  static const totalWidth = thumbWidth + 2 * (railWidth + _railGap);
  static const _minThumbHeight = 24.0;
  static const _railAlpha = 0.4;

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
        final railColor = color.withValues(alpha: _railAlpha);
        return LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final thumbH = (visibleFrac * h).clamp(_minThumbHeight, h);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Left rail — full-height fixed line.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: ColoredBox(color: railColor),
                ),
                // Right rail.
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: ColoredBox(color: railColor),
                ),
                // Thumb — horizontally centered between the rails,
                // vertical position from `scrollFrac`. Align(0, -1)
                // puts child flush at the top, (0, +1) at the bottom
                // — so `scrollFrac * 2 - 1` maps [0, 1] → [-1, +1].
                Align(
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
                ),
              ],
            );
          },
        );
      },
    );
  }
}
