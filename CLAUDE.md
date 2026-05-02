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
- `integration_test/goldens/*_test.dart` — golden-image regression
  suite, captures pixel-exact PNGs of the load-bearing visual
  surfaces. Golden filename pivots on the device's current
  `MediaQuery.platformBrightness`, so the same test contributes
  `<surface>_light.png` on a light-mode pass and `<surface>_dark.png`
  on a dark-mode pass.

The same `test_harness.dart` powers these. Don't call
`tester.pumpAndSettle()` after triggering an animation in the app —
some animations (sparkle, glitter outline draw-in) run for a known
window; pump past them with `tester.pump(Duration(milliseconds: ...))`.
`pumpAndSettle` is fine for opening dialogs / sheets / page swipes.

### Regenerating goldens

Goldens at `integration_test/goldens/goldens/*.png` are pixel-exact —
any drift fails CI. Regenerate when the SDK, emulator image, or a
load-bearing widget changes:

```sh
adb shell "cmd uimode night no"
flutter test integration_test/goldens/ -d emulator-5554 --update-goldens
adb shell "cmd uimode night yes"
flutter test integration_test/goldens/ -d emulator-5554 --update-goldens
adb shell "cmd uimode night no"   # restore
```

Eyeball the diffs (`git diff -- '*.png'` shows new vs old) before
committing — accidental visual changes should NOT regenerate
silently.

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

### Toggling system dark mode

The QA runner's `BRIGHTNESS=light|dark` `--dart-define` is an *in-app*
override — it forces `MediaQuery(platformBrightness: ...)` from inside
the test harness. It does **not** change the emulator's system dark
mode, which is what `MaterialApp.themeMode: ThemeMode.system` reads.

To actually flip the emulator's system dark mode:

```sh
adb shell "cmd uimode night yes"   # turn dark mode ON
adb shell "cmd uimode night no"    # turn dark mode OFF
adb shell "cmd uimode night auto"  # follow system schedule
```

Confirmed working on API 34 (the project's CI emulator). The change
broadcasts a config change immediately; the running app rebuilds with
the new brightness on the next frame — no app restart needed.

This is what the CI integration job does between its two passes:
`cmd uimode night no` → run integration tests → `cmd uimode night yes`
→ run again. Both passes must be green.

For local QA: useful when you want to confirm an actual dark-system
render rather than the in-app override.

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

`.github/workflows/ci.yml` runs the following on `push` to
`main` and on every `pull_request`:

- `Analyze` — `flutter analyze`
- `Unit + widget tests` — `flutter test`
- `Integration tests (<suite> / <mode>)` — a 6-entry matrix
  (`{items, lists, goldens} × {light, dark}`). Each entry boots
  its own Android API 34 emulator via
  `reactivecircus/android-emulator-runner@v2`, flips system dark
  mode (`adb shell cmd uimode night yes/no`), and runs the one
  test file for that suite via `tool/ci_flutter_test.sh`.

If the integration job fails locally but passes in CI (or vice
versa), it's almost always animation timing or device pixel ratio.
Re-pin the timed pumps before assuming a logic bug.

### CI gotchas — read before changing the integration lane

The CI pipeline's current shape exists because of a stack of
real, demonstrated runner / SDK / framework fragilities. Each
piece below is load-bearing:

- **The 6-entry matrix.** Do **NOT** collapse back to one job
  per brightness. The runner's emulator dies after ~7 apk
  install/uninstall cycles, and combined items + lists +
  goldens (~13 tests) overflows that ceiling. The matrix split
  caps each emulator at the test count of one suite.
- **`tool/ci_flutter_test.sh` wraps `flutter test`.** It
  swallows post-test cleanup noise (`PathNotFoundException` on
  `/tmp/flutter_tools.*`, `adb uninstall failed`) which fires
  on a successful goldens run. Real test failures still
  propagate (it greps for `Test failed` / `Some tests failed` /
  `FAIL ` and honors them). Do not bypass.
- **`integration_test/flutter_test_config.dart` installs a
  tolerant `LocalFileComparator`.** ≤0.01% pixel diff is
  treated as pass. GPU / font / decoder run-to-run noise
  routinely produces 1–3 px diffs on identical renders;
  pixel-exact comparison would flag them as failures.
- **Goldens are consolidated** into one
  `integration_test/goldens/all_goldens_test.dart` with five
  `testWidgets` calls. **Do not add new `*_test.dart` files to
  `integration_test/goldens/`** — each new file forces a fresh
  apk install/uninstall, and 5+ cycles per emulator overflows
  the ceiling. New golden surfaces add a `testWidgets` to the
  consolidated file.
- **`subosito/flutter-action@v2` uses `channel: stable`.** That
  channel floats; a stable-channel update was the proximate
  cause of the May 2026 drift that required this whole pipeline
  reshape. If drift recurs, the right structural fix is to pin
  `flutter-version: <x.y.z>` in the workflow rather than
  chasing the drift downstream.

### When CI fails on a PR

Before deep-diving into how your diff might have caused it:

1. `gh run list --branch main --workflow ci.yml --limit 5` —
   does `main` show the same failure? Two PRs have already
   merged over their own failing CI here; "merged" ≠ "had
   passing CI."
2. If `main` is also failing on the same job, the diff is
   inherited-innocent. Open a separate fix PR off `main` for
   the runner-drift issue and rebase the feature branch on
   top once it lands.
3. Only after `main` is verified clean should you consider
   diff-caused failures.

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
