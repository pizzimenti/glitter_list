import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// Golden: per-list empty-state hero (caticorn image + "Empty list."
/// line) on the actual emulator, with the bg-image bake fully resolved
/// (real GPU raster path) and frosted strip rendered behind the empty-
/// state text.
///
/// Brightness comes from the device's system mode (set by
/// `adb shell cmd uimode night yes/no` between CI passes), so the same
/// test file runs twice — captures `..._light.png` on the light pass
/// and `..._dark.png` on the dark pass. The matched filename is read
/// from MediaQuery.platformBrightness AFTER mount so it tracks whatever
/// mode the device is in at that moment.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
}
