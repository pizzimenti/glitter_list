import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/todo_list.dart';

class HiveRepository {
  static const _boxName = 'glitter_list';
  static const _listsKey = 'lists';

  Box? _box;

  Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  List<TodoList> load() {
    final box = _box;
    if (box == null) return [];
    final raw = box.get(_listsKey);
    if (raw is! List) return [];
    final result = <TodoList>[];
    for (final entry in raw.whereType<Map>()) {
      try {
        result.add(TodoList.fromMap(entry));
      } catch (_) {
        // Skip malformed entries so one bad record doesn't drop the whole store.
      }
    }
    return result;
  }

  Future<void> save(List<TodoList> lists) async {
    final box = _box;
    if (box == null) return;
    await box.put(_listsKey, lists.map((e) => e.toMap()).toList());
  }
}
