import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_state.dart';

part 'theme_mode.g.dart';

/// Persisted user override for [MaterialApp.themeMode]. The hamburger
/// menu's 3-segment picker (sun / auto / moon) writes through `set`;
/// the chosen value is written to Hive immediately and re-read on
/// next cold launch via [HiveRepository.loadThemeMode].
@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() => ref.read(hiveRepositoryProvider).loadThemeMode();

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(hiveRepositoryProvider).saveThemeMode(mode);
  }
}
