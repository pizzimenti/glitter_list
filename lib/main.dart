import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models/todo_item.dart';
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
  final seeded = repo.hasSeeded();
  // Gate on a one-shot Hive flag, NOT on `lists.isEmpty` — otherwise a
  // user who deletes every list via the popup menu has the seed
  // content resurrected on next cold launch (their `[]` looks
  // identical to a never-written box). The flag is set the first time
  // we seed and never unset. Backfill the flag for upgraded installs
  // that already have data — they pre-date the seeded marker, and
  // without backfill they'd hit the "deleted everything → resurrect
  // seed" trap the first time they empty their list collection.
  if (!seeded) {
    if (lists.isEmpty) {
      lists = _seedLists();
      await repo.save(lists);
    }
    await repo.markSeeded();
  }

  final initial = AppState(lists: lists, currentListIndex: 0);

  runApp(ProviderScope(
    overrides: [
      appStateProvider.overrideWith((ref) => AppStateNotifier(repo, initial)),
    ],
    child: const GlitterListApp(),
  ));
}

/// Seed content for first-launch when the Hive box is empty. Five themed
/// lists, each 6–12 ordinary "girl things" entries — gives the parallax,
/// scroll, and tile UI something realistic to render before the user has
/// added their own data.
List<TodoList> _seedLists() {
  final uuid = const Uuid();
  TodoItem item(String text) => TodoItem(id: uuid.v4(), text: text);
  TodoList list(String name, List<String> texts) => TodoList(
        id: uuid.v4(),
        name: name,
        items: texts.map(item).toList(),
      );

  return [
    list('Self-Care ✨', const [
      'Vitamin C serum',
      'Reapply SPF',
      'Lip balm',
      'Dry brush before shower',
      'Hair mask on Sunday',
      'Pilates class',
      'Magnesium before bed',
      'Replace toothbrush head',
      'Refill perfume',
    ]),
    list('Wishlist 💖', const [
      'Linen dress from Reformation',
      'Aritzia tube top',
      'Tatcha rice polish',
      'Le Labo Santal 33 sample',
      'Sol de Janeiro mist',
      'New running shoes (HOKA?)',
      'Gold huggies',
      'Silk pillowcase',
      'Skims tank in dune',
      'Birkenstock Bostons',
      'Stanley straw replacement',
    ]),
    list('Groceries 🛒', const [
      'Oat milk',
      'Sparkling water variety pack',
      'Dark chocolate (90%)',
      'Raspberries',
      'Sourdough loaf',
      'Hummus + carrots',
      'Eggs',
      'Greek yogurt',
      'Fresh basil',
      'Lemons',
      'Coffee beans',
      'Hot honey',
    ]),
    list('Weekend 🌷', const [
      'Brunch with Jess @ 11',
      'Farmers market — bring tote',
      'Pedicure Sat 2pm',
      'Past Lives rewatch',
      'Yoga sculpt Sun morning',
      'Golden hour walk',
      'Call grandma',
    ]),
    list('Tidy Up 🧹', const [
      'Wash sheets',
      'Repot the monstera',
      'Donate closet pile',
      'Organize bathroom drawer',
      'Wipe down skincare shelf',
      'Vacuum',
    ]),
  ];
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
