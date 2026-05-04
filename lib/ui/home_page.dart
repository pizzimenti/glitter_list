import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/theme_mode.dart';
import 'add_list_sheet.dart';
import 'baked_bg.dart';
import 'glitter_theme.dart';
import 'list_page.dart';
import 'per_line_backdrop_blur.dart';
import 'pre_baked_backdrop.dart';
import 'text_prompt_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    // PageController + vertical-scroll progress + repaint listenable
    // live in BgParallaxHost (above MaterialApp). All three references
    // are stable for the app's lifetime, so reading them from the
    // controls scope does NOT make HomePage rebuild on every parallax
    // tick — the bg-layer AnimatedBuilder below handles per-tick
    // repaints by reading `BgParallaxScope` from inside its builder.
    final controls = BgParallaxControls.of(context);

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

    // Scale the bg image past `cover` so panning has slack on BOTH
    // axes. The scale is asymmetric — 1.48 horizontal / 1.39 vertical
    // — so horizontal pan has ~60% more travel than vertical (matches
    // the requested motion ratio: bigger horizontal swing on swipe
    // than vertical swing on scroll). The Transform wraps only the bg
    // layer; the Scaffold sits on top, untouched.
    //
    // Saturation is boosted on the image (Rec. 709 luminance, s=1.3)
    // for an HDR-like pop. The matching `alignment` + `listenable`
    // are published from BgParallaxHost above MaterialApp; each
    // PreBakedBackdrop strip reads them via BgParallaxScope to sample
    // the matching slice of the pre-baked, pre-blurred bg image and
    // force-repaint per scroll frame.
    return AnimatedBuilder(
      animation: controls.bgListenable,
      builder: (context, child) {
        final parallax = BgParallaxScope.maybeOf(context);
        final alignment = parallax?.alignment ?? Alignment.center;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: surface),
            ClipRect(
              child: Transform(
                // Scale + saturation matrix come from `baked_bg.dart`
                // so the live bg layer here and the pre-baked image
                // sampled by per-line frosted strips read the SAME
                // numbers. Drift between the two would misalign each
                // strip tonally and geometrically vs. the surrounding
                // sharp bg.
                transform: Matrix4.diagonal3Values(
                  bgParallaxScale.width,
                  bgParallaxScale.height,
                  1,
                ),
                alignment: alignment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(bgAsset),
                      fit: BoxFit.cover,
                      colorFilter: bgSaturationFilterFor(brightness),
                    ),
                  ),
                ),
              ),
            ),
            ?child,
          ],
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
                  case 'theme-light':
                    await ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.light);
                  case 'theme-system':
                    await ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.system);
                  case 'theme-dark':
                    await ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.dark);
                }
              },
              itemBuilder: (_) {
                final mode = ref.read(themeModeProvider);
                return [
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
                  _ThemeSegmentMenuItem(currentMode: mode),
                ];
              },
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
                  if (controls.verticalT.value != t) {
                    controls.verticalT.value = t;
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: controls.controller,
                  itemCount: state.lists.length,
                  onPageChanged: (i) {
                    // New list comes in at scroll offset 0 → bg back to top.
                    controls.verticalT.value = -1;
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
      builder: (_) => TextPromptDialog(
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
      builder: (_) => const TextPromptDialog(
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

/// Three-segment theme picker (sun / auto / moon) embedded in the
/// hamburger menu in place of a single cycling toggle. The whole row
/// is one [PopupMenuItem] but each segment dispatches its own
/// `theme-<mode>` action via `Navigator.pop(context, value)` — the
/// outer `onSelected` switch handler reads that value and persists
/// the choice through `themeModeProvider`. `enabled: false` on the
/// outer item disables the default tap-anywhere-to-pop behavior so
/// the segments are the only interactive surface.
///
/// The disabled-state styling that Material applies to the child
/// (an `IconTheme` with `opacity: 0.38` plus a `disabledColor`-tinted
/// `DefaultTextStyle`) is undone inside the row by re-wrapping with
/// an `IconTheme.merge(opacity: 1.0)` and a `DefaultTextStyle.merge`
/// at the surface-onColor — otherwise the icons + labels look greyed
/// out as if not-interactable, which they explicitly are.
class _ThemeSegmentMenuItem extends PopupMenuItem<String> {
  _ThemeSegmentMenuItem({required ThemeMode currentMode})
      : super(
          enabled: false,
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: _ThemeSegmentRow(currentMode: currentMode),
        );
}

class _ThemeSegmentRow extends StatelessWidget {
  const _ThemeSegmentRow({required this.currentMode});

  final ThemeMode currentMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconTheme.merge(
      data: IconThemeData(opacity: 1.0, color: scheme.onSurface),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Theme',
                style: TextStyle(
                  fontSize: 18,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ThemeSegment(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Light',
                  selected: currentMode == ThemeMode.light,
                  actionValue: 'theme-light',
                ),
                _ThemeSegment(
                  icon: Icons.brightness_auto_outlined,
                  label: 'Auto',
                  selected: currentMode == ThemeMode.system,
                  actionValue: 'theme-system',
                ),
                _ThemeSegment(
                  icon: Icons.nightlight_outlined,
                  label: 'Dark',
                  selected: currentMode == ThemeMode.dark,
                  actionValue: 'theme-dark',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.actionValue,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String actionValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary.withValues(alpha: 0.18) : null;
    final fg = selected ? scheme.primary : scheme.onSurface;
    return InkWell(
      onTap: () => Navigator.of(context).pop<String>(actionValue),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 28, color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 18, color: fg),
            ),
          ],
        ),
      ),
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
    // Mirrors PerLineBackdropBlur — Theme.of follows the
    // MaterialApp.themeMode override so the page-dot bake stays in
    // sync with the rest of the app's brightness.
    final brightness = Theme.of(context).brightness;
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
            duration: const Duration(milliseconds: 400),
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


