import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'add_list_sheet.dart';
import 'baked_bg.dart';
import 'glitter_theme.dart';
import 'list_page.dart';
import 'per_line_backdrop_blur.dart';
import 'pre_baked_backdrop.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final PageController _controller;
  // Background's vertical pan, mapped from the active list's scroll
  // offset into [-1, +1]. Drives `Alignment(_, y)` on the bg image so
  // glitter pans down as the list scrolls down. Starts at -1 (top of
  // image, matching an unscrolled list). Per-line frosted strips no
  // longer source from a live BackdropFilter (they sample a pre-baked
  // ui.Image) so we can update this on every ScrollUpdateNotification
  // without re-introducing the engine's vertical-scroll tearing race.
  final ValueNotifier<double> _verticalT = ValueNotifier(-1);
  late final Listenable _bgListenable;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: ref.read(appStateProvider).currentListIndex,
    );
    _bgListenable = Listenable.merge([_controller, _verticalT]);
  }

  @override
  void dispose() {
    _verticalT.dispose();
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
        (screenWidth - 16 - 48 - 16).clamp(100.0, double.infinity);
    // Honor the user's system text scale. Without this, measured height
    // underestimates the rendered Text when accessibility font-scaling
    // is on, which can clip long titles at the bottom of the AppBar.
    final measured = TextPainter(
      text: TextSpan(text: titleText, style: titleStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 3,
    )..layout(maxWidth: titleMaxWidth);
    final measuredHeight = measured.height;
    measured.dispose();
    final toolbarHeight = math.max(kToolbarHeight, measuredHeight + 24);

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final bgAsset = brightness == Brightness.dark
        ? 'assets/images/bg_dark.png'
        : 'assets/images/bg_light.png';
    final surface = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _bgListenable,
      builder: (context, child) {
        final maxIndex = state.lists.length - 1;
        double alignmentX = 0;
        if (maxIndex > 0) {
          // Before the controller has clients (first frame) `page` throws,
          // so fall back to the initial index until the PageView attaches.
          final page = _controller.hasClients
              ? (_controller.page ?? state.currentListIndex.toDouble())
              : state.currentListIndex.toDouble();
          alignmentX = ((page / maxIndex) * 2 - 1).clamp(-1.0, 1.0);
        }
        final alignment = Alignment(alignmentX, _verticalT.value);
        // Scale the bg image past `cover` so panning has slack on BOTH
        // axes. The scale is asymmetric — 1.48 horizontal / 1.39 vertical
        // — so horizontal pan has ~60% more travel than vertical (matches
        // the requested motion ratio: bigger horizontal swing on swipe
        // than vertical swing on scroll). The Transform wraps only the bg
        // layer; the Scaffold sits on top, untouched.
        //
        // Saturation is boosted on the image (Rec. 709 luminance, s=1.3)
        // for an HDR-like pop. The same parallax `alignment` and the
        // merged `_bgListenable` are pushed into BgParallaxScope so each
        // PreBakedBackdrop strip can sample the matching slice of the
        // pre-baked, pre-blurred bg image and force-repaint per scroll
        // frame.
        return BgParallaxScope(
          parallax: BgParallax(
            listenable: _bgListenable,
            alignment: alignment,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: surface),
              ClipRect(
                child: Transform(
                  transform: Matrix4.diagonal3Values(1.48, 1.39, 1),
                  alignment: alignment,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(bgAsset),
                        fit: BoxFit.cover,
                        // Saturation matrix, s=1.3, Rec. 709 weights:
                        // sr = (1-s)*0.2126, sg = (1-s)*0.7152, sb = (1-s)*0.0722.
                        colorFilter: const ColorFilter.matrix(<double>[
                          1.23622, -0.21456, -0.02166, 0, 0,
                          -0.06378, 1.08544, -0.02166, 0, 0,
                          -0.06378, -0.21456, 1.27834, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              ?child,
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: toolbarHeight,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                // Align without widthFactor fills the Expanded slot but
                // hands a loose constraint to PerLineBackdropBlur, which
                // sizes itself to the laid-out text — per-line strips,
                // tight to each line's content. AppBar isn't inside any
                // scrollable so this stays ungrouped.
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PerLineBackdropBlur(
                    text: titleText,
                    style: titleStyle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          bottom: state.lists.length > 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: _PageDots(
                    count: state.lists.length,
                    index: state.currentListIndex,
                  ),
                )
              : null,
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
                      await _confirmDeleteList(
                          currentList.id, currentList.name);
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
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Vertical scrolls bubble up from the inner ReorderableListView;
                  // PageView's own horizontal scrolls bubble up too and are ignored.
                  if (n.metrics.axis != Axis.vertical) return false;
                  // Same nullability gotcha as _ScrollIndicator: ScrollMetrics
                  // exposes pixels / viewportDimension / maxScrollExtent through
                  // !-guarded getters, so we only read them once the underlying
                  // position has finished its first layout.
                  if (!n.metrics.hasContentDimensions ||
                      !n.metrics.hasPixels ||
                      !n.metrics.hasViewportDimension) {
                    return false;
                  }
                  // Mapping: alignmentY = -1 + 2 * pixels / max(extent, 2*viewport).
                  // For short scrollable lists the denominator is 2*viewport, so
                  // bg moves at ~15% of text-scroll speed (matching the slow
                  // parallax feel of the horizontal swipe). For very long lists
                  // the denominator is the actual scroll extent, and bg pans the
                  // full slack across the list — even slower per pixel.
                  final viewport = n.metrics.viewportDimension;
                  final extent = n.metrics.maxScrollExtent;
                  final denom =
                      extent > 2 * viewport ? extent : 2 * viewport;
                  final t = denom > 0
                      ? (-1 + 2 * n.metrics.pixels / denom).clamp(-1.0, 1.0)
                      : -1.0;
                  if (_verticalT.value != t) _verticalT.value = t;
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: state.lists.length,
                  onPageChanged: (i) {
                    // New list comes in at scroll offset 0 → bg back to top.
                    _verticalT.value = -1;
                    notifier.switchList(i);
                  },
                  itemBuilder: (_, i) {
                    final list = state.lists[i];
                    // Key by the list's stable id so PageView preserves
                    // the right ListPage state across mutations. Without
                    // this, deleting/reordering lists can cause a new
                    // page to inherit the previous occupant's
                    // ScrollController / scroll-indicator state because
                    // PageView.builder reuses State by index, not
                    // identity.
                    return ListPage(key: ValueKey(list.id), list: list);
                  },
                ),
              ),
        floatingActionButton: currentList == null
            ? null
            : FloatingActionButton(
                onPressed: () => _promptAddItem(currentList.id),
                child: const Icon(Icons.add),
              ),
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
          height: 80,
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
        Icon(icon, size: 28),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(fontSize: 24)),
      ],
    );
  }
}

class _PageDots extends ConsumerWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (count <= 1) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.onSurface;
    final brightness = MediaQuery.platformBrightnessOf(context);
    final viewportSize = MediaQuery.sizeOf(context);
    final baked = ref
        .watch(bakedBgProvider(
            BakedBgKey(brightness: brightness, size: viewportSize)))
        .value;
    final dots = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 12 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
    if (baked == null) return dots;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ClipRect(child: PreBakedBackdrop(baked: baked)),
        ),
        dots,
      ],
    );
  }
}
