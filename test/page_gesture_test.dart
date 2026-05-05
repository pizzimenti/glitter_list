import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/state/app_state.dart';

import 'helpers/test_harness.dart';

void main() {
  group('Page gestures', () {
    testWidgets('mostly vertical drag on a short list does not switch pages', (
      tester,
    ) async {
      final container = await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: Scenarios.multiList3(),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 0);

      await tester.timedDrag(
        find.byType(PageView),
        const Offset(24, -420),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('early sideways jitter does not start a page drag', (
      tester,
    ) async {
      final container = await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: Scenarios.multiList3(),
      );
      await tester.pumpAndSettle();

      final item = find.text('Pilates');
      final startX = tester.getTopLeft(item).dx;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );

      await gesture.moveBy(const Offset(-12, -4));
      await tester.pump();
      for (var i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(-8, -70));
        await tester.pump();
      }

      expect(tester.getTopLeft(item).dx, moreOrLessEquals(startX, epsilon: 1));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('25-degree horizontal drag switches pages', (tester) async {
      final container = await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: Scenarios.multiList3(),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 0);

      await tester.timedDrag(
        find.byType(PageView),
        const Offset(-360, -168),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('horizontal drag still switches pages', (tester) async {
      final container = await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: Scenarios.multiList3(),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 0);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.timedDrag(
        find.byType(PageView),
        Offset(-size.width * 0.8, 8),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(container.read(appStateProvider).currentListIndex, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
