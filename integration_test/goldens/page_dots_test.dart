import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// Golden: page-dot strip with 3 lists. Tiny but exercises `_PageDots`'s
/// `PreBakedBackdrop` — validates the bake renders behind small UI
/// elements, not just per-line text strips.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('page dots strip', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.multiList3());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/page_dots_${brightness.name}.png'),
    );
  });
}
