import 'package:hive_flutter/hive_flutter.dart';

import '../models/todo_list.dart';

class HiveRepository {
  static const _boxName = 'glitter_list';
  static const _listsKey = 'lists';

  late final Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  List<TodoList> load() {
    final raw = _box.get(_listsKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(TodoList.fromMap)
        .toList();
  }

  Future<void> save(List<TodoList> lists) async {
    await _box.put(_listsKey, lists.map((e) => e.toMap()).toList());
  }
}
