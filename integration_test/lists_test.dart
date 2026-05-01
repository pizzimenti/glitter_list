import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

/// List-management integration tests: create a list from the popup menu,
/// switch between lists via horizontal swipe.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('List management', () {
    testWidgets('create list — popup → New List → AddListSheet → submit',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.empty(),
      );
      await tester.pump();
      expect(container.read(appStateProvider).lists, isEmpty);

      // Open the AppBar PopupMenu and tap "New List".
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New List'));
      await tester.pumpAndSettle();

      // AddListSheet is on screen. Type, hit Create.
      await tester.enterText(find.byType(TextField), 'Weekend');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      final lists = container.read(appStateProvider).lists;
      expect(lists.length, 1);
      expect(lists.first.name, 'Weekend');
      expect(tester.takeException(), isNull);
    });

    testWidgets('switch lists — horizontal swipe advances currentListIndex',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.multiList3(),
      );
      await tester.pump();
      expect(container.read(appStateProvider).currentListIndex, 0);

      // Drag the PageView left by ~80% of screen width to flip one page.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.timedDrag(
        find.byType(PageView),
        Offset(-size.width * 0.8, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
