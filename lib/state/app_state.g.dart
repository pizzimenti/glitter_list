// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hiveRepository)
final hiveRepositoryProvider = HiveRepositoryProvider._();

final class HiveRepositoryProvider
    extends $FunctionalProvider<HiveRepository, HiveRepository, HiveRepository>
    with $Provider<HiveRepository> {
  HiveRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiveRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiveRepositoryHash();

  @$internal
  @override
  $ProviderElement<HiveRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HiveRepository create(Ref ref) {
    return hiveRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HiveRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HiveRepository>(value),
    );
  }
}

String _$hiveRepositoryHash() => r'c20f7110c7f16342f3e14431db055c59a26542af';

@ProviderFor(initialAppState)
final initialAppStateProvider = InitialAppStateProvider._();

final class InitialAppStateProvider
    extends $FunctionalProvider<AppState, AppState, AppState>
    with $Provider<AppState> {
  InitialAppStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialAppStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialAppStateHash();

  @$internal
  @override
  $ProviderElement<AppState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppState create(Ref ref) {
    return initialAppState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppState>(value),
    );
  }
}

String _$initialAppStateHash() => r'8dd42ca82eb337870e9f273480cc44b4a48102e6';

@ProviderFor(AppStateNotifier)
final appStateProvider = AppStateNotifierProvider._();

final class AppStateNotifierProvider
    extends $NotifierProvider<AppStateNotifier, AppState> {
  AppStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appStateNotifierHash();

  @$internal
  @override
  AppStateNotifier create() => AppStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppState>(value),
    );
  }
}

String _$appStateNotifierHash() => r'db8991d39dd68ca378e4d9d78efe0368432501f4';

abstract class _$AppStateNotifier extends $Notifier<AppState> {
  AppState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AppState, AppState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppState, AppState>,
              AppState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
