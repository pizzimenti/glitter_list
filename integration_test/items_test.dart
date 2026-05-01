import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

/// Item-lifecycle integration tests: add, edit, toggle done (strikethrough
/// path), long-press menu (Glitter, Delete), and drag-reorder. Each test
/// seeds with [Scenarios.singleListShort] (or a richer state where
/// reorder needs a recognizable starting order).
///
/// Assertion strategy: read [appStateProvider] off the [ProviderContainer]
/// returned by [pumpAppWith]. Pixel-level assertions (rainbow strikethrough,
/// glitter outline) are PR 2's golden-image territory; here we verify the
/// behavioral state lands.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Item lifecycle', () {
    testWidgets('add item — FAB opens dialog, submit appends to current list',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('New item'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Refill perfume');
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();

      final items = container.read(appStateProvider).lists[0].items;
      expect(items.last.text, 'Refill perfume');
      expect(items.length, 4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edit item — long-press → Edit changes the persisted text',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      await tester.longPress(find.text('Pilates 5pm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Edit'));
      await tester.pumpAndSettle();

      // The inline TextField now hosts the item's text — replace it.
      await tester.enterText(find.byType(TextField).first, 'Pilates 6pm');
      // Submit closes the inline edit (via onSubmitted in TodoTile).
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final item = container.read(appStateProvider).lists[0].items[1];
      expect(item.text, 'Pilates 6pm');
      expect(tester.takeException(), isNull);
    });

    testWidgets('toggle done — tap checkbox flips done flag', (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      await tester.tap(find.byType(Checkbox).first);
      // Pump past _checkCtrl (1s, one-shot) so the strikethrough animation
      // completes and any in-flight rebuilds settle.
      await tester.pump(const Duration(milliseconds: 1100));

      final item = container.read(appStateProvider).lists[0].items[0];
      expect(item.done, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Long-press menu', () {
    testWidgets('Glitter Item — sets glittered flag on the target item',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      await tester.longPress(find.text('Call grandma'));
      await tester.pumpAndSettle();
      expect(find.text('Glitter Item'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Glitter Item'));
      await tester.pumpAndSettle();

      final item = container.read(appStateProvider).lists[0].items[2];
      expect(item.glittered, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Delete — removes the target item from the list',
        (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      await tester.longPress(find.text('Pilates 5pm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
      await tester.pumpAndSettle();

      final items = container.read(appStateProvider).lists[0].items;
      expect(items.length, 2);
      expect(items.map((i) => i.text), ['Buy oat milk', 'Call grandma']);
      expect(tester.takeException(), isNull);
    });
  });

  group('Reorder via drag handle', () {
    testWidgets('drag first item downward reorders the list', (tester) async {
      final container = await pumpAppWith(
        tester,
        initial: Scenarios.singleListShort(),
      );
      await tester.pump();

      // Drag the first drag-handle down past at least one tile. Exact
      // resulting position depends on the device's tile height — assert
      // on the meaningful behavioral property: the first item is no
      // longer 'Buy oat milk', and all three items are still present.
      final firstHandle = find.byIcon(Icons.drag_handle).first;
      await tester.timedDrag(
        firstHandle,
        const Offset(0, 200),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      final items = container.read(appStateProvider).lists[0].items;
      expect(items.length, 3);
      expect(items.first.text, isNot('Buy oat milk'),
          reason: 'drag reorder must move "Buy oat milk" out of slot 0');
      expect(
        items.map((i) => i.text).toSet(),
        {'Buy oat milk', 'Pilates 5pm', 'Call grandma'},
        reason: 'reorder must preserve every item',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
