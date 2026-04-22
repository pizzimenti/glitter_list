import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/todo_item.dart';
import '../models/todo_list.dart';
import '../storage/hive_repository.dart';

class AppState {
  const AppState({required this.lists, required this.currentListIndex});

  final List<TodoList> lists;
  final int currentListIndex;

  AppState copyWith({List<TodoList>? lists, int? currentListIndex}) => AppState(
        lists: lists ?? this.lists,
        currentListIndex: currentListIndex ?? this.currentListIndex,
      );
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._repo, AppState initial) : super(initial);

  final HiveRepository _repo;
  final _uuid = Uuid();

  Future<void> _persist() => _repo.save(state.lists);

  TodoList _requireList(String id) =>
      state.lists.firstWhere((l) => l.id == id);

  void switchList(int index) {
    if (index < 0 || index >= state.lists.length) return;
    if (index == state.currentListIndex) return;
    state = state.copyWith(currentListIndex: index);
  }

  Future<void> addList(String name) async {
    final list = TodoList(id: _uuid.v4(), name: name);
    state = state.copyWith(
      lists: [...state.lists, list],
      currentListIndex: state.lists.length,
    );
    await _persist();
  }

  Future<void> renameList(String id, String name) async {
    _requireList(id).name = name;
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }

  Future<void> deleteList(String id) async {
    final idx = state.lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final next = [...state.lists]..removeAt(idx);
    final newIndex = next.isEmpty
        ? 0
        : state.currentListIndex.clamp(0, next.length - 1);
    state = AppState(lists: next, currentListIndex: newIndex);
    await _persist();
  }

  Future<void> addItem(String listId, String text) async {
    final list = _requireList(listId);
    list.items.add(TodoItem(id: _uuid.v4(), text: text));
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }

  Future<void> toggleItem(String listId, String itemId) async {
    final item = _requireList(listId).items.firstWhere((i) => i.id == itemId);
    item.done = !item.done;
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }

  Future<void> editItemText(String listId, String itemId, String text) async {
    final item = _requireList(listId).items.firstWhere((i) => i.id == itemId);
    item.text = text;
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }

  Future<void> deleteItem(String listId, String itemId) async {
    _requireList(listId).items.removeWhere((i) => i.id == itemId);
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }

  Future<void> reorderItem(String listId, int oldIndex, int newIndex) async {
    final items = _requireList(listId).items;
    if (oldIndex < 0 || oldIndex >= items.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, items.length - 1);
    final moved = items.removeAt(oldIndex);
    items.insert(target, moved);
    state = state.copyWith(lists: [...state.lists]);
    await _persist();
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  throw UnimplementedError('Override appStateProvider in ProviderScope');
});
