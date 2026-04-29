import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/todo_list.dart';
import 'state/app_state.dart';
import 'storage/hive_repository.dart';
import 'ui/glitter_colors.dart';
import 'ui/glitter_theme.dart';
import 'ui/home_page.dart';

void _installErrorHandlers() {
  if (kDebugMode) {
    // Flush error lines immediately instead of batching via the default
    // rate-limited debugPrint.
    debugPrint = debugPrintSynchronously;
  }
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      '[glitter-error] framework: ${details.exceptionAsString()}\n'
      '${details.stack}',
    );
  };
  // Return false so the platform's default reporting still runs; we only
  // log, we don't mark the error as handled.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[glitter-error] async: $error\n$stack');
    return false;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();

  final repo = HiveRepository();
  await repo.init();

  var lists = repo.load();
  if (lists.isEmpty) {
    lists = [TodoList(id: Uuid().v4(), name: 'My Glitter List ✨')];
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

  static const _titleFontSize = 30.0;
  static const _bodyFontSize = 22.0;

  ColorScheme _schemeFor(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: GlitterColors.accent,
      brightness: brightness,
    );
    return base.copyWith(
      surface: GlitterColors.bgFor(brightness),
      onSurface: GlitterColors.chromeFor(brightness),
      primary: GlitterColors.accent,
      onPrimary: GlitterColors.onAccent,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = _schemeFor(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Sniglet',
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GlitterColors.accent,
        foregroundColor: GlitterColors.onAccent,
        sizeConstraints: BoxConstraints.tightFor(width: 67.2, height: 67.2),
        iconSize: 28,
      ),
      extensions: [
        GlitterTheme(
          content: GlitterColors.contentFor(brightness),
          titleFontSize: _titleFontSize,
          bodyFontSize: _bodyFontSize,
        ),
      ],
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
