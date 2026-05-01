import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// Golden: a single item with `glittered: true` so
/// `GlitterOutline._SquigglePainter` paints at progress=1 on the first
/// frame. Isolates the squiggle's alignment to its line metrics — if
/// per-line alignment ever drifts vs. the underlying TextPainter, this
/// catches it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('glitter outline end-state', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.glitteredEndState());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = MediaQuery.platformBrightnessOf(
      tester.element(find.byType(GlitterListApp)),
    );

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/glitter_outline_${brightness.name}.png'),
    );
  });
}
