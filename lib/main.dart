import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/todo_list.dart';
import 'state/app_state.dart';
import 'storage/hive_repository.dart';
import 'ui/glitter_colors.dart';
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

  ColorScheme _schemeFor(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: GlitterColors.hotPink,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? GlitterColors.deepPurple : GlitterColors.lightPink;
    final fg = isDark ? GlitterColors.lightPink : GlitterColors.deepPurple;
    return base.copyWith(
      surface: bg,
      onSurface: fg,
      primary: GlitterColors.hotPink,
      onPrimary: Colors.white,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = _schemeFor(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Sniglet',
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glitter List',
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
