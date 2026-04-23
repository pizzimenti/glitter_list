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
    final idx = state.lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final lists = [...state.lists];
    lists[idx] = lists[idx].copyWith(name: name);
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> deleteList(String id) async {
    final idx = state.lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final next = [...state.lists]..removeAt(idx);
    var candidate = state.currentListIndex;
    if (idx < candidate) candidate -= 1;
    final newIndex = next.isEmpty ? 0 : candidate.clamp(0, next.length - 1);
    state = AppState(lists: next, currentListIndex: newIndex);
    await _persist();
  }

  Future<void> addItem(String listId, String text) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final lists = [...state.lists];
    lists[idx] = lists[idx].copyWith(
      items: [...lists[idx].items, TodoItem(id: _uuid.v4(), text: text)],
    );
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> toggleItem(String listId, String itemId) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final list = state.lists[idx];
    final itemIdx = list.items.indexWhere((i) => i.id == itemId);
    if (itemIdx < 0) return;
    final items = [...list.items];
    items[itemIdx] = items[itemIdx].copyWith(done: !items[itemIdx].done);
    final lists = [...state.lists];
    lists[idx] = list.copyWith(items: items);
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> editItemText(String listId, String itemId, String text) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final list = state.lists[idx];
    final itemIdx = list.items.indexWhere((i) => i.id == itemId);
    if (itemIdx < 0) return;
    final items = [...list.items];
    items[itemIdx] = items[itemIdx].copyWith(text: text);
    final lists = [...state.lists];
    lists[idx] = list.copyWith(items: items);
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> clearCompleted(String listId) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final list = state.lists[idx];
    final remaining = list.items.where((i) => !i.done).toList();
    if (remaining.length == list.items.length) return;
    final lists = [...state.lists];
    lists[idx] = list.copyWith(items: remaining);
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> deleteItem(String listId, String itemId) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final list = state.lists[idx];
    if (!list.items.any((i) => i.id == itemId)) return;
    final lists = [...state.lists];
    lists[idx] = list.copyWith(
      items: list.items.where((i) => i.id != itemId).toList(),
    );
    state = state.copyWith(lists: lists);
    await _persist();
  }

  Future<void> reorderItem(String listId, int oldIndex, int newIndex) async {
    final idx = state.lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    final list = state.lists[idx];
    if (oldIndex < 0 || oldIndex >= list.items.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, list.items.length - 1);
    final items = [...list.items];
    final moved = items.removeAt(oldIndex);
    items.insert(target, moved);
    final lists = [...state.lists];
    lists[idx] = list.copyWith(items: items);
    state = state.copyWith(lists: lists);
    await _persist();
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  throw UnimplementedError('Override appStateProvider in ProviderScope');
});
