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
/// dependency providers overridden, plus a forced [Brightness] via
/// MediaQuery so tests don't depend on the host's system theme.
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
  Brightness brightness = Brightness.light,
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
      child: MediaQuery(
        data: MediaQueryData(platformBrightness: brightness),
        child: const GlitterListApp(),
      ),
    ),
  );
  return container;
}
