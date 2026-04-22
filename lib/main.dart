import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/todo_list.dart';
import 'state/app_state.dart';
import 'storage/hive_repository.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = HiveRepository();
  await repo.init();

  var lists = repo.load();
  if (lists.isEmpty) {
    lists = [TodoList(id: Uuid().v4(), name: 'My List')];
    await repo.save(lists);
  }

  final initial = AppState(lists: lists, currentListIndex: 0);

  runApp(ProviderScope(
    overrides: [
      appStateProvider.overrideWith((ref) => AppStateNotifier(repo, initial)),
    ],
    child: const GlitterListApp(),
  ));
}

class GlitterListApp extends StatelessWidget {
  const GlitterListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glitter List',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}
