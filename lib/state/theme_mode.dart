import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_state.dart';

part 'theme_mode.g.dart';

/// Persisted user override for [MaterialApp.themeMode]. The hamburger
/// menu cycles `system → light → dark → system`; the chosen value is
/// written to Hive immediately and re-read on next cold launch via
/// [HiveRepository.loadThemeMode].
@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() => ref.read(hiveRepositoryProvider).loadThemeMode();

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(hiveRepositoryProvider).saveThemeMode(mode);
  }

  /// Cycles the override `system → light → dark → system`. Used by the
  /// single hamburger-menu toggle so the user can flip between modes
  /// without surfacing three separate menu entries.
  Future<void> cycle() {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    return set(next);
  }
}
