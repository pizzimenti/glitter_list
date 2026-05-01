# Claude — working on Glitter List

This file is for Claude. The user's README is for humans.

## What this project is

Flutter app, Android + iOS, local-only multi-list todo. Riverpod 3 with
codegen, Hive (community fork `hive_ce`) for persistence, custom
glittery rendering (per-line frosted strips, rainbow strikethrough,
sparkles, glitter outlines).

## Build / codegen

Generated files (`lib/state/*.g.dart`) are committed. After editing a
`@riverpod`-annotated class:

```sh
dart run build_runner build --delete-conflicting-outputs
```

CI does not run codegen — the committed `*.g.dart` is the source of
truth there.

## Static analysis

```sh
flutter analyze
```

Must be clean before pushing.

## Unit + widget tests

```sh
flutter test
```

Lives under `test/`. Two files:

- `test/app_state_test.dart` — `AppStateNotifier` business logic
- `test/widget_smoke_test.dart` — full-app pump across a size/state/brightness matrix

Both share helpers from `test/helpers/test_harness.dart`:

- `pumpAppWith(tester, ...)` — pumps `GlitterListApp` with deps
  overridden via Riverpod, returns a `ProviderContainer` for state
  assertions.
- `buildNotifier(initial)` — for tests that exercise the notifier
  directly without a widget tree.

## Integration tests

```sh
flutter test integration_test/ -d emulator-5554
```

Runs on a real device or emulator. Exists under `integration_test/`:

- `integration_test/items_test.dart` — add/edit item, toggle done,
  long-press menu (Glitter / Delete), drag-reorder.
- `integration_test/lists_test.dart` — create list, switch lists by
  swipe.

The same `test_harness.dart` powers these. Don't call
`tester.pumpAndSettle()` after triggering an animation in the app —
some animations (sparkle, glitter outline draw-in) run for a known
window; pump past them with `tester.pump(Duration(milliseconds: ...))`.
`pumpAndSettle` is fine for opening dialogs / sheets / page swipes.

## Driving the emulator (live QA, not tests)

The `tool/qa_main.dart` runner boots the app on a deterministic
in-memory state — ideal for taking screenshots, exploring a flow
visually, or verifying a render before/after a UI tweak.

```sh
# List available scenarios:
grep -E '^  static AppState ' lib/dev/scenarios.dart

# Boot a scenario on the running emulator:
flutter run -t tool/qa_main.dart -d emulator-5554 \
  --dart-define=SCENARIO=mixedDoneGlittered \
  --dart-define=BRIGHTNESS=light
```

Defaults: `SCENARIO=mixedDoneGlittered`, `BRIGHTNESS=light`. Unknown
scenario names log a warning and fall back to the default rather than
throwing.

Capture and inspect the current frame:

```sh
adb exec-out screencap -p > /tmp/qa_shot.png
# then Read /tmp/qa_shot.png — the multimodal Read tool renders PNGs
```

Drive the UI (coordinates are device-local; check `adb shell wm size`):

```sh
adb shell input tap X Y
adb shell input text "Hello"
adb shell input swipe X1 Y1 X2 Y2 DURATION_MS
adb shell input keyevent KEYCODE_BACK
```

Why scenarios? The real `main()` reads from Hive, which means every
launch picks up whatever state the user (or the previous session)
left there. The QA runner uses `InMemoryRepository` from `lib/dev/`,
so every launch is a clean slate seeded from `Scenarios`.

## Conventions

- **Per-PR version bump.** Every feature PR bumps `pubspec.yaml`'s
  `version:` and adds a `CHANGELOG.md` entry under a new SemVer
  heading. Surface "Release — 0.X.Y" in the PR description.
- **Keep a Changelog** format. Sections are `### Added`, `### Changed`,
  `### Fixed`, `### Notes`.
- **Branch naming**: `feat/<short-slug>` for features, `fix/<slug>`
  for bugfixes.
- **Post-merge cleanup**: delete the local feature branch with
  `git branch -D <name>` immediately after the squash-merge lands.

## CI

`.github/workflows/ci.yml` runs three jobs in parallel on `push` to
`main` and on every `pull_request`:

- `Analyze` — `flutter analyze`
- `Unit + widget tests` — `flutter test`
- `Integration tests (Android emulator)` — boots an Android API 34
  emulator via `reactivecircus/android-emulator-runner@v2` and runs
  `flutter test integration_test/`. ~10 min total per run; cancels
  in-flight runs when a new commit lands.

If the integration job fails locally but passes in CI (or vice
versa), it's almost always animation timing or device pixel ratio.
Re-pin the timed pumps before assuming a logic bug.

## Files Claude tends to touch

- `lib/state/app_state.dart` — Riverpod notifier, the central state.
- `lib/ui/home_page.dart` — top-level scaffold, AppBar, FAB, parallax bg.
- `lib/ui/list_page.dart` — per-list scrollable + scroll indicator.
- `lib/ui/todo_tile.dart` — per-item tile, the recently-tweaked spacing.
- `lib/ui/check_animation.dart` — `RainbowStrikethrough`,
  `GlowingCheckbox`, `SparkleBurst`.
- `lib/ui/glitter_outline.dart` — the glitter-item squiggle painter.
- `lib/dev/in_memory_repository.dart` — the test/QA fake.
- `lib/dev/scenarios.dart` — named seed states.
- `tool/qa_main.dart` — the QA runner entry.
