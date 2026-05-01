import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/main.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/helpers/test_harness.dart';

/// Golden: AppBar with a wrapped multi-line title. The AppBar's frosted
/// strip is ungrouped (`BackdropGroup` only wraps the body), so this
/// surface validates a different render path from the per-tile strips.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppBar wrapped title', (tester) async {
    await pumpAppWith(tester, initial: Scenarios.longTitle());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final brightness = goldenBrightness();

    await expectLater(
      find.byType(GlitterListApp),
      matchesGoldenFile('goldens/appbar_title_${brightness.name}.png'),
    );
  });
}
