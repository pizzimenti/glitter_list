import 'package:flutter/material.dart';

import '../models/todo_list.dart';
import '../storage/hive_repository.dart';

/// In-memory replacement for [HiveRepository] used by tests and the
/// `tool/qa_main.dart` runner. No path-provider plugin, no disk I/O —
/// scenarios stay deterministic and runs are clean slates.
///
/// Round-trips `save → load` so `AppStateNotifier` behaves the same way
/// it would on real Hive: writing state and reading it back returns the
/// same lists. The `saveCalls` counter is kept so unit tests can assert
/// "this mutation persisted exactly once."
class InMemoryRepository extends HiveRepository {
  List<TodoList> _stored = const [];
  bool _seeded = false;
  int saveCalls = 0;

  @override
  Future<void> init() async {}

  @override
  List<TodoList> load() => List<TodoList>.from(_stored);

  @override
  Future<void> save(List<TodoList> lists) async {
    saveCalls++;
    _stored = List<TodoList>.from(lists);
  }

  @override
  bool hasSeeded() => _seeded;

  @override
  Future<void> markSeeded() async {
    _seeded = true;
  }

  ThemeMode _themeMode = ThemeMode.system;

  @override
  ThemeMode loadThemeMode() => _themeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    _themeMode = mode;
  }
}
