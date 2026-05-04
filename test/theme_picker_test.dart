import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/models/todo_item.dart';
import 'package:glitter_list/models/todo_list.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:glitter_list/state/theme_mode.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets(
    'tapping a theme segment changes the mode without closing the menu',
    (tester) async {
      // Roomier-than-default surface so Material's popup menu has
      // enough horizontal space for the 24 px-font menu rows. The
      // default 800×600 test surface is too tall-and-thin and the
      // popup's max-width ratio gives less room than the rows want;
      // a 900×1200 surface lets the menu render the 'Clear Completed'
      // / 'Delete List' rows without RenderFlex overflow.
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Single-list scenario so the hamburger menu has its standard
      // entries plus the theme picker; default theme mode is `system`
      // (InMemoryRepository's `loadThemeMode` returns it).
      final container = await pumpAppWith(
        tester,
        brightness: Brightness.light,
        initial: const AppState(
          lists: [
            TodoList(
              id: 'L1',
              name: 'Mix',
              items: [TodoItem(id: 'L1-i0', text: 'first')],
            ),
          ],
          currentListIndex: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.system);

      // Open the AppBar's hamburger PopupMenuButton.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);

      // Tap the Dark segment by its text label.
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Mode switched to dark.
      expect(container.read(themeModeProvider), ThemeMode.dark);
      // Menu is still open: the picker's other segments and the
      // standard menu rows are still in the tree.
      expect(
        find.text('Theme'),
        findsOneWidget,
        reason: 'menu should stay open after a segment tap',
      );
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('New List'), findsOneWidget);

      // Tap Auto to confirm a SECOND segment tap also keeps the menu
      // open and re-flips the mode without re-opening.
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(find.text('Theme'), findsOneWidget);
    },
  );
}
