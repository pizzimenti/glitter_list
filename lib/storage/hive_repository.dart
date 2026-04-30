import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/todo_list.dart';

class HiveRepository {
  static const _boxName = 'glitter_list';
  static const _listsKey = 'lists';
  static const _seededKey = 'seeded';

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

  /// True once `markSeeded()` has been called and persisted on a prior run.
  /// Used by the bootstrap to distinguish "first launch" from "user has
  /// emptied every list" — we only seed sample content in the former.
  bool hasSeeded() {
    final box = _box;
    if (box == null) return false;
    return box.get(_seededKey, defaultValue: false) as bool;
  }

  Future<void> markSeeded() async {
    final box = _box;
    if (box == null) return;
    await box.put(_seededKey, true);
  }
}
