import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// All five golden surfaces in one file — co-located on purpose so
/// `flutter test integration_test/goldens/` builds and installs the
/// debug apk *once* and runs all five tests in a single emulator
/// session. Splitting this into per-file tests caused the CI runner
/// emulator to die after ~5 apk install/uninstall cycles, taking
/// the dark-mode pass down with it.
///
/// Brightness comes from the device's system mode (set by
/// `adb shell cmd uimode night yes/no` between CI passes), so each
/// test reads `goldenBrightness()` AFTER mount and selects its
/// golden filename by the current platform brightness. The same
/// file therefore contributes 5 PNGs per brightness pass.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Per-list empty-state hero (caticorn image + "Empty list." line)
  // on the actual emulator, with the bg-image bake fully resolved
  // (real GPU raster path) and frosted strip rendered behind the
  // empty-state text.
  testWidgets('empty state hero', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.singleListEmpty());
    // pumpAndSettle drains the bake + asset loads on real GPU. End-state
    // seed has no animations triggered, so settle is fast.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/empty_state_${brightness.name}.png'),
    );
  });

  // A single item with `glittered: true` so
  // `GlitterOutline._SquigglePainter` paints at progress=1 on the
  // first frame. Isolates the squiggle's alignment to its line
  // metrics — if per-line alignment ever drifts vs. the underlying
  // TextPainter, this catches it.
  testWidgets('glitter outline end-state', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.glitteredEndState());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/glitter_outline_${brightness.name}.png'),
    );
  });

  // Page-dot strip with 3 lists. Tiny but exercises `_PageDots`'s
  // `PreBakedBackdrop` — validates the bake renders behind small UI
  // elements, not just per-line text strips.
  testWidgets('page dots strip', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.multiList3());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/page_dots_${brightness.name}.png'),
    );
  });

  // AppBar with a wrapped multi-line title. The AppBar's frosted
  // strip is ungrouped (`BackdropGroup` only wraps the body), so
  // this surface validates a different render path from the
  // per-tile strips.
  testWidgets('AppBar wrapped title', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.longTitle());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/appbar_title_${brightness.name}.png'),
    );
  });

  // Flagship list surface — every item state represented (plain,
  // done with rainbow strikethrough at value=1, glittered with
  // outline squiggle at value=1, done+glittered, multi-line wrap).
  // Captures the broadest set of visual signals in one image.
  testWidgets('list with mixed item states', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.mixedDoneGlittered());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/list_mixed_${brightness.name}.png'),
    );
  });

  // Trailing no-op test. The post-May-2026 CI emulator + flutter_test
  // reporter combo hits a race where the genuinely-last test's pass
  // result doesn't reconcile into the final "🎉 N tests passed"
  // summary, even though the test itself prints its ✅ and the
  // comparator approved its golden. Symptoms: counter is
  // off-by-one and the job exits 1. Putting a cheap, fast,
  // pixel-comparison-free test in the trailing slot lets the slow
  // golden tests above it close cleanly while this one is the one
  // whose tail-end reconciliation gets lost. Cost: ~1 second of
  // wall-clock per pass. Remove if the underlying flutter_test
  // reporter behavior is fixed.
  testWidgets('trailing reconciliation no-op', (tester) async {
    await pumpAppWith(
      tester,
      initial: const AppState(lists: [], currentListIndex: 0),
    );
    expect(find.byType(GlitterListApp), findsOneWidget);
  });
}
