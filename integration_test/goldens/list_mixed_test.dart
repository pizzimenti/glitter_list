import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// Golden: flagship list surface — every item state represented (plain,
/// done with rainbow strikethrough at value=1, glittered with outline
/// squiggle at value=1, done+glittered, multi-line wrap). Captures the
/// broadest set of visual signals in one image.
///
/// Runs against device system brightness; the CI emulator flips
/// `cmd uimode night` between passes so this test contributes one PNG
/// per brightness.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('list with mixed item states', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.mixedDoneGlittered());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = MediaQuery.platformBrightnessOf(
      tester.element(find.byType(GlitterListApp)),
    );

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/list_mixed_${brightness.name}.png'),
    );
  });
}
