// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persisted user override for [MaterialApp.themeMode]. The hamburger
/// menu cycles `system → light → dark → system`; the chosen value is
/// written to Hive immediately and re-read on next cold launch via
/// [HiveRepository.loadThemeMode].

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// Persisted user override for [MaterialApp.themeMode]. The hamburger
/// menu cycles `system → light → dark → system`; the chosen value is
/// written to Hive immediately and re-read on next cold launch via
/// [HiveRepository.loadThemeMode].
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, ThemeMode> {
  /// Persisted user override for [MaterialApp.themeMode]. The hamburger
  /// menu cycles `system → light → dark → system`; the chosen value is
  /// written to Hive immediately and re-read on next cold launch via
  /// [HiveRepository.loadThemeMode].
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'23a12d51b23bb402120134de6d50fb362d3d6af3';

/// Persisted user override for [MaterialApp.themeMode]. The hamburger
/// menu cycles `system → light → dark → system`; the chosen value is
/// written to Hive immediately and re-read on next cold launch via
/// [HiveRepository.loadThemeMode].

abstract class _$ThemeModeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
