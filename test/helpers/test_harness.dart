import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glitter_list/dev/in_memory_repository.dart';
import 'package:glitter_list/main.dart';
import 'package:glitter_list/state/app_state.dart';
import 'package:glitter_list/storage/hive_repository.dart';

export 'package:glitter_list/dev/in_memory_repository.dart';
export 'package:glitter_list/dev/scenarios.dart';

/// Build a [ProviderContainer] with [hiveRepositoryProvider] and
/// [initialAppStateProvider] overridden. Used by unit tests that want
/// to exercise [AppStateNotifier] directly without a widget tree.
///
/// The container is auto-disposed via [addTearDown] so per-test cleanup
/// is implicit.
({InMemoryRepository repo, AppStateNotifier notifier}) buildNotifier(
  AppState initial, {
  InMemoryRepository? repo,
}) {
  final repository = repo ?? InMemoryRepository();
  final container = ProviderContainer(overrides: [
    hiveRepositoryProvider.overrideWithValue(repository),
    initialAppStateProvider.overrideWithValue(initial),
  ]);
  addTearDown(container.dispose);
  return (
    repo: repository,
    notifier: container.read(appStateProvider.notifier),
  );
}

/// Pump [GlitterListApp] wrapped in a [ProviderScope] with the
/// dependency providers overridden, plus an optional forced
/// [Brightness] via MediaQuery so tests don't depend on the host's
/// system theme.
///
/// When [brightness] is omitted (the integration-test path on a real
/// emulator), the test inherits the device's actual platform brightness
/// — useful when CI flips system dark mode via
/// `adb shell cmd uimode night yes` between passes. In that case the
/// app is mounted directly under [UncontrolledProviderScope] without a
/// MediaQuery wrapper, so Flutter's automatic root MediaQuery (driven
/// by the device) reaches [MaterialApp] and `ThemeMode.system` resolves
/// against the real platform brightness.
///
/// Returns the [ProviderContainer] so callers can assert directly on
/// state (`container.read(appStateProvider)`) without spelunking the
/// widget tree. The container is auto-disposed via [addTearDown].
///
/// Don't use [WidgetTester.pumpAndSettle] anywhere in this app — the
/// sparkle and glitter outline animations include indefinitely-running
/// loops that never settle. Use timed pumps (`tester.pump(Duration)`)
/// to advance past a known animation window instead. (Widget smoke
/// tests use `pumpAndSettle` only because they exit before any
/// animation has been triggered; integration tests must use timed
/// pumps once they've tapped anything that animates.)
Future<ProviderContainer> pumpAppWith(
  WidgetTester tester, {
  Brightness? brightness,
  HiveRepository? repo,
  AppState? initial,
}) async {
  final repository = repo ?? InMemoryRepository();
  final state = initial ?? const AppState(lists: [], currentListIndex: 0);
  final container = ProviderContainer(overrides: [
    hiveRepositoryProvider.overrideWithValue(repository),
    initialAppStateProvider.overrideWithValue(state),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: brightness == null
          ? const GlitterListApp()
          : MediaQuery(
              data: MediaQueryData(platformBrightness: brightness),
              child: const GlitterListApp(),
            ),
    ),
  );
  return container;
}

