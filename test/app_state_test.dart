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
}
