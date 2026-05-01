import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/models/todo_item.dart';
import 'package:glitter_list/models/todo_list.dart';
import 'package:glitter_list/state/app_state.dart';

import 'helpers/test_harness.dart';

/// Build a [TodoList] with [count] simple items. Item ids are stable and
/// distinct across the whole tree so [ReorderableListView]'s key
/// uniqueness check is satisfied.
TodoList _listWith({
  required String id,
  required String name,
  required int count,
}) {
  return TodoList(
    id: id,
    name: name,
    items: List.generate(
      count,
      (i) => TodoItem(id: '$id-item-$i', text: 'item $i'),
    ),
  );
}

Future<void> _pumpAndAssertNoErrors(
  WidgetTester tester, {
  required Brightness brightness,
  required AppState initial,
}) async {
  await pumpAppWith(tester, brightness: brightness, initial: initial);
  // First explicit frame: state attached but pre-layout. This is the
  // window where _ScrollIndicator previously threw "Null check operator
  // used on a null value" via ScrollPosition's !-guarded metric getters.
  await tester.pump();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
}

/// Cases for the size matrix. Each case rebuilds its [AppState] freshly
/// so per-test mutations don't leak between runs.
final _sizeCases = <({String name, AppState Function() build})>[
  (
    name: '0 lists (empty AppState)',
    build: () => const AppState(lists: [], currentListIndex: 0),
  ),
  (
    name: '1 list with 0 items',
    build: () => AppState(
          lists: [_listWith(id: 'L1', name: 'Empty', count: 0)],
          currentListIndex: 0,
        ),
  ),
  (
    name: '1 list with 1 item',
    build: () => AppState(
          lists: [_listWith(id: 'L1', name: 'One', count: 1)],
          currentListIndex: 0,
        ),
  ),
  (
    name: '1 list with 5 items',
    build: () => AppState(
          lists: [_listWith(id: 'L1', name: 'Five', count: 5)],
          currentListIndex: 0,
        ),
  ),
  (
    name: '1 list with 50 items (scrollable — _ScrollIndicator path)',
    build: () => AppState(
          lists: [_listWith(id: 'L1', name: 'Fifty', count: 50)],
          currentListIndex: 0,
        ),
  ),
  (
    name: '3 lists with mixed sizes (5, 50, 0)',
    build: () => AppState(
          lists: [
            _listWith(id: 'L1', name: 'Five', count: 5),
            _listWith(id: 'L2', name: 'Fifty', count: 50),
            _listWith(id: 'L3', name: 'Zero', count: 0),
          ],
          currentListIndex: 0,
        ),
  ),
];

void main() {
  group('GlitterListApp smoke — list size matrix', () {
    for (final c in _sizeCases) {
      for (final brightness in Brightness.values) {
        testWidgets('${c.name} — ${brightness.name}', (tester) async {
          await _pumpAndAssertNoErrors(
            tester,
            brightness: brightness,
            initial: c.build(),
          );
        });
      }
    }
  });

  group('GlitterListApp smoke — scroll exercise', () {
    testWidgets(
      'long list (50 items) survives a vertical drag without throwing',
      (tester) async {
        final state = AppState(
          lists: [_listWith(id: 'L1', name: 'Fifty', count: 50)],
          currentListIndex: 0,
        );
        await pumpAppWith(
          tester,
          brightness: Brightness.light,
          initial: state,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Drag the inner reorderable list upward. Use the scrollable
        // belonging to the list, not the outer PageView, so the gesture
        // exercises ScrollPosition layout/pixel updates that previously
        // tripped _ScrollIndicator's null-check crash.
        final scrollable = find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      },
    );
  });
}
