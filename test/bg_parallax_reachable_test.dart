import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:glitter_list/ui/baked_bg.dart';

import 'helpers/test_harness.dart';

/// Guards the whole point of hoisting [BgParallaxHost] above
/// [MaterialApp]: anything reparented into Navigator's root [Overlay]
/// (showDialog, PopupMenuButton, ReorderableListView's drag proxy)
/// must still be able to read [BgParallaxScope]. If a future refactor
/// re-nests the scope below the Overlay, this test fails before any
/// frosted-glass overlay surface ships visibly broken.
///
/// `showDialog` and `PopupMenuButton` both reparent into the same
/// Navigator overlay, so one dialog test covers both paths.
void main() {
  testWidgets(
    'BgParallaxScope is reachable from inside a showDialog route',
    (tester) async {
      await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: const AppState(lists: [], currentListIndex: 0),
      );
      await tester.pumpAndSettle();

      BgParallax? captured;
      // Anchor the dialog to a context inside the live app (any
      // descendant of MaterialApp's Navigator) so showDialog uses the
      // same root Overlay the popup-menu / drag-proxy paths use.
      final anchor = tester.element(find.byType(Scaffold));
      final dialog = showDialog<void>(
        context: anchor,
        builder: (dialogContext) {
          captured = BgParallaxScope.maybeOf(dialogContext);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpAndSettle();

      expect(
        captured,
        isNotNull,
        reason: 'BgParallaxScope must be reachable from inside a dialog '
            'route — that is the whole point of hoisting BgParallaxHost '
            'above MaterialApp.',
      );

      // Tidy up the dialog so the test framework doesn't flag a leaked
      // route on tearDown.
      Navigator.of(anchor).pop();
      await tester.pumpAndSettle();
      await dialog;
    },
  );
}
