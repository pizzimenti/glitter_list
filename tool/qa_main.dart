import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glitter_list/dev/in_memory_repository.dart';
import 'package:glitter_list/dev/scenarios.dart';
import 'package:glitter_list/main.dart';
import 'package:glitter_list/state/app_state.dart';

/// Alternate `main` entry that boots the app on top of an
/// [InMemoryRepository] seeded with one of the [Scenarios] — no Hive
/// on disk, no risk of clobbering the user's real data, every launch
/// starts in the same known state.
///
/// Usage:
///
/// ```sh
/// flutter run -t tool/qa_main.dart -d emulator-5554 \
///   --dart-define=SCENARIO=mixedDoneGlittered \
///   --dart-define=BRIGHTNESS=light
/// ```
///
/// Defaults: `SCENARIO=mixedDoneGlittered`, `BRIGHTNESS=light`.
///
/// Unknown scenario names fall back to the default with a debug log
/// rather than throwing — keeps the runner forgiving when Claude
/// types a name that's been renamed or removed.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint = debugPrintSynchronously;
  }
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      '[glitter-error] framework: ${details.exceptionAsString()}\n'
      '${details.stack}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[glitter-error] async: $error\n$stack');
    return false;
  };

  const scenarioName =
      String.fromEnvironment('SCENARIO', defaultValue: Scenarios.defaultName);
  const brightnessName =
      String.fromEnvironment('BRIGHTNESS', defaultValue: 'light');

  var resolvedName = scenarioName;
  var initial = Scenarios.byName(scenarioName);
  if (initial == null) {
    debugPrint(
      '[qa] unknown scenario "$scenarioName"; '
      'falling back to "${Scenarios.defaultName}". '
      'Known: ${Scenarios.names.join(", ")}',
    );
    resolvedName = Scenarios.defaultName;
    initial = Scenarios.byName(Scenarios.defaultName)!;
  }
  final brightness = brightnessName == 'dark' ? Brightness.dark : Brightness.light;

  debugPrint(
    '[qa] booting scenario="$resolvedName" '
    'brightness="${brightness.name}" '
    'lists=${initial.lists.length}',
  );

  runApp(
    ProviderScope(
      overrides: [
        hiveRepositoryProvider.overrideWithValue(InMemoryRepository()),
        initialAppStateProvider.overrideWithValue(initial),
      ],
      child: MediaQuery(
        data: MediaQueryData(platformBrightness: brightness),
        child: const GlitterListApp(),
      ),
    ),
  );
}
