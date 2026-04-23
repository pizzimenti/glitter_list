import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/models/todo_item.dart';
import 'package:glitter_list/models/todo_list.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:glitter_list/storage/hive_repository.dart';

class _FakeRepo extends HiveRepository {
  int saveCalls = 0;
  @override
  Future<void> init() async {}
  @override
  List<TodoList> load() => [];
  @override
  Future<void> save(List<TodoList> lists) async {
    saveCalls++;
  }
}

void main() {
  group('AppStateNotifier.reorderItem', () {
    late _FakeRepo repo;
    late AppStateNotifier notifier;

    setUp(() {
      repo = _FakeRepo();
      final list = TodoList(id: 'L1', name: 'List 1', items: [
        TodoItem(id: 'A', text: 'a'),
        TodoItem(id: 'B', text: 'b'),
        TodoItem(id: 'C', text: 'c'),
      ]);
      notifier = AppStateNotifier(
        repo,
        AppState(lists: [list], currentListIndex: 0),
      );
    });

    List<String> currentIds() => notifier.state.lists
        .firstWhere((l) => l.id == 'L1')
        .items
        .map((i) => i.id)
        .toList();

    test('moves item down (ReorderableListView convention)', () async {
      // ReorderableListView sends newIndex = 2 when dropping A between B and C.
      await notifier.reorderItem('L1', 0, 2);
      expect(currentIds(), ['B', 'A', 'C']);
      expect(repo.saveCalls, 1);
    });

    test('moves item up', () async {
      await notifier.reorderItem('L1', 2, 0);
      expect(currentIds(), ['C', 'A', 'B']);
    });

    test('moves item to the very end (newIndex == length)', () async {
      await notifier.reorderItem('L1', 0, 3);
      expect(currentIds(), ['B', 'C', 'A']);
    });

    test('out-of-range oldIndex is a no-op and does not persist', () async {
      await notifier.reorderItem('L1', 99, 0);
      expect(currentIds(), ['A', 'B', 'C']);
      expect(repo.saveCalls, 0);
    });
  });

  group('AppStateNotifier.switchList', () {
    late AppStateNotifier notifier;

    setUp(() {
      notifier = AppStateNotifier(
        _FakeRepo(),
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'a'),
            TodoList(id: 'L2', name: 'b'),
            TodoList(id: 'L3', name: 'c'),
          ],
          currentListIndex: 0,
        ),
      );
    });

    test('updates currentListIndex for valid index', () {
      notifier.switchList(2);
      expect(notifier.state.currentListIndex, 2);
    });

    test('negative index is rejected', () {
      notifier.switchList(-1);
      expect(notifier.state.currentListIndex, 0);
    });

    test('index >= length is rejected', () {
      notifier.switchList(5);
      expect(notifier.state.currentListIndex, 0);
    });

    test('same index is a no-op (state reference unchanged)', () {
      final before = notifier.state;
      notifier.switchList(0);
      expect(identical(notifier.state, before), isTrue);
    });
  });

  group('AppStateNotifier.deleteList', () {
    late AppStateNotifier notifier;

    setUp(() {
      notifier = AppStateNotifier(
        _FakeRepo(),
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'a'),
            TodoList(id: 'L2', name: 'b'),
            TodoList(id: 'L3', name: 'c'),
          ],
          currentListIndex: 2,
        ),
      );
    });

    test('deleting a list before the current one decrements selection', () async {
      // Regression: previously only clamped, so current would stay at 2 when
      // L1 was removed, silently shifting selection from L3 to what was L2.
      await notifier.deleteList('L1');
      expect(notifier.state.lists.map((l) => l.id), ['L2', 'L3']);
      expect(notifier.state.currentListIndex, 1);
      expect(notifier.state.lists[notifier.state.currentListIndex].id, 'L3');
    });

    test('deleting the current list keeps index but clamps into range', () async {
      await notifier.deleteList('L3');
      expect(notifier.state.lists.map((l) => l.id), ['L1', 'L2']);
      expect(notifier.state.currentListIndex, 1);
    });

    test('deleting a list after the current one leaves selection alone', () async {
      notifier.switchList(0);
      await notifier.deleteList('L3');
      expect(notifier.state.lists.map((l) => l.id), ['L1', 'L2']);
      expect(notifier.state.currentListIndex, 0);
    });

    test('deleting the last list resets index to 0', () async {
      await notifier.deleteList('L1');
      await notifier.deleteList('L2');
      await notifier.deleteList('L3');
      expect(notifier.state.lists, isEmpty);
      expect(notifier.state.currentListIndex, 0);
    });

    test('unknown id is a no-op', () async {
      await notifier.deleteList('does-not-exist');
      expect(notifier.state.lists.length, 3);
      expect(notifier.state.currentListIndex, 2);
    });
  });

  group('AppStateNotifier immutability', () {
    late _FakeRepo repo;
    late AppStateNotifier notifier;

    setUp(() {
      repo = _FakeRepo();
      notifier = AppStateNotifier(
        repo,
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'L1', items: [
              TodoItem(id: 'A', text: 'a'),
              TodoItem(id: 'B', text: 'b', done: true),
            ]),
          ],
          currentListIndex: 0,
        ),
      );
    });

    test('toggleItem does not mutate prior state snapshot', () async {
      final before = notifier.state;
      final beforeItem = before.lists[0].items[0];
      await notifier.toggleItem('L1', 'A');
      expect(beforeItem.done, isFalse,
          reason: 'prior item reference must not be mutated in place');
      expect(notifier.state.lists[0].items[0].done, isTrue);
      expect(identical(before, notifier.state), isFalse);
    });

    test('editItemText does not mutate prior snapshot', () async {
      final before = notifier.state;
      final beforeItem = before.lists[0].items[1];
      await notifier.editItemText('L1', 'B', 'renamed');
      expect(beforeItem.text, 'b');
      expect(notifier.state.lists[0].items[1].text, 'renamed');
    });

    test('renameList does not mutate prior snapshot', () async {
      final before = notifier.state;
      final beforeList = before.lists[0];
      await notifier.renameList('L1', 'new name');
      expect(beforeList.name, 'L1');
      expect(notifier.state.lists[0].name, 'new name');
    });

    test('addItem does not mutate prior list items', () async {
      final before = notifier.state;
      final beforeItems = before.lists[0].items;
      final beforeLength = beforeItems.length;
      await notifier.addItem('L1', 'c');
      expect(beforeItems.length, beforeLength);
      expect(notifier.state.lists[0].items.length, beforeLength + 1);
    });
  });

  group('AppStateNotifier unknown-id guards', () {
    late _FakeRepo repo;
    late AppStateNotifier notifier;

    setUp(() {
      repo = _FakeRepo();
      notifier = AppStateNotifier(
        repo,
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'L1', items: [
              TodoItem(id: 'A', text: 'a'),
            ]),
          ],
          currentListIndex: 0,
        ),
      );
    });

    test('addItem to unknown list is a no-op (no throw, no persist)', () async {
      await notifier.addItem('does-not-exist', 'x');
      expect(notifier.state.lists[0].items.length, 1);
      expect(repo.saveCalls, 0);
    });

    test('toggleItem on unknown list is a no-op', () async {
      await notifier.toggleItem('does-not-exist', 'A');
      expect(notifier.state.lists[0].items[0].done, isFalse);
      expect(repo.saveCalls, 0);
    });

    test('toggleItem with unknown item id is a no-op', () async {
      await notifier.toggleItem('L1', 'does-not-exist');
      expect(notifier.state.lists[0].items[0].done, isFalse);
      expect(repo.saveCalls, 0);
    });

    test('editItemText with unknown item id is a no-op', () async {
      await notifier.editItemText('L1', 'does-not-exist', 'x');
      expect(notifier.state.lists[0].items[0].text, 'a');
      expect(repo.saveCalls, 0);
    });

    test('deleteItem with unknown item id is a no-op', () async {
      await notifier.deleteItem('L1', 'does-not-exist');
      expect(notifier.state.lists[0].items.length, 1);
      expect(repo.saveCalls, 0);
    });

    test('renameList with unknown id is a no-op', () async {
      await notifier.renameList('does-not-exist', 'x');
      expect(notifier.state.lists[0].name, 'L1');
      expect(repo.saveCalls, 0);
    });

    test('reorderItem on unknown list is a no-op', () async {
      await notifier.reorderItem('does-not-exist', 0, 1);
      expect(repo.saveCalls, 0);
    });
  });

  group('AppStateNotifier.clearCompleted', () {
    late _FakeRepo repo;
    late AppStateNotifier notifier;

    setUp(() {
      repo = _FakeRepo();
      notifier = AppStateNotifier(
        repo,
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'L1', items: [
              TodoItem(id: 'A', text: 'a'),
              TodoItem(id: 'B', text: 'b', done: true),
              TodoItem(id: 'C', text: 'c', done: true),
              TodoItem(id: 'D', text: 'd'),
            ]),
          ],
          currentListIndex: 0,
        ),
      );
    });

    test('removes only done items, preserves order of remaining', () async {
      await notifier.clearCompleted('L1');
      final items = notifier.state.lists[0].items;
      expect(items.map((i) => i.id), ['A', 'D']);
      expect(repo.saveCalls, 1);
    });

    test('no-op when nothing is done (and does not persist)', () async {
      notifier = AppStateNotifier(
        repo,
        AppState(
          lists: [
            TodoList(id: 'L1', name: 'L1', items: [
              TodoItem(id: 'A', text: 'a'),
              TodoItem(id: 'B', text: 'b'),
            ]),
          ],
          currentListIndex: 0,
        ),
      );
      await notifier.clearCompleted('L1');
      expect(notifier.state.lists[0].items.length, 2);
      expect(repo.saveCalls, 0);
    });

    test('unknown listId is a no-op', () async {
      await notifier.clearCompleted('does-not-exist');
      expect(notifier.state.lists[0].items.length, 4);
      expect(repo.saveCalls, 0);
    });

    test('does not mutate prior state snapshot', () async {
      final before = notifier.state;
      final beforeItems = before.lists[0].items;
      await notifier.clearCompleted('L1');
      expect(beforeItems.map((i) => i.id), ['A', 'B', 'C', 'D']);
      expect(notifier.state.lists[0].items.map((i) => i.id), ['A', 'D']);
    });
  });
}
