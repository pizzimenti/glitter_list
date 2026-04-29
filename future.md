# Future work

A living scratchpad of candidate work for Glitter List. **Not a commitment list.** Items get added, reordered, shipped, or dropped without ceremony. Priority and ordering shift as the project does — this doc is here to remember ideas, not to plan sprints.

When an item ships, delete its entry. Git history and `CHANGELOG.md` are the archive.

## How entries are structured

Each entry has these fields, in this order:

- **Status** — one of: `Candidate` (interesting, not committed), `Next-up` (likely soon), `Parked` (considered and deferred — say why)
- **Priority** — `High` / `Medium` / `Low`, gut feel
- **Why** — what motivated the idea
- **Scope** — what's actually involved (files, surface area, unknowns)
- **Risk / cost** — rough effort + what could go sideways
- **Depends on** — gating items, if any

Entries live under the single `## Candidates` heading below. Status is a tag on each entry, not a section — that way reordering or re-prioritizing is a one-line edit, not a move between silos.

## Candidates

### Migrate to Riverpod 3 (with codegen)

**Status:** Candidate
**Priority:** Medium

**Why.** The scaffold (PR #1, 2026-04-22) pulled `flutter_riverpod ^2.5.1` by inertia, not by deliberate choice — Riverpod 3 was already the current major. The codegen path (`@riverpod` annotation) is the modern idiom and produces materially less boilerplate than the hand-rolled `StateNotifierProvider` style in use today. The codebase is small enough that this is bounded work; doing it later, with more providers and call sites in place, is strictly more expensive.

**Scope.** Surface area is small (verified against current source):

- One provider: `appStateProvider` (`StateNotifierProvider<AppStateNotifier, AppState>`) at `lib/state/app_state.dart:145`.
- One notifier: `AppStateNotifier extends StateNotifier<AppState>` at `lib/state/app_state.dart:20`.
- One `ProviderScope` at `lib/main.dart:49` with an `overrideWith` injecting the seeded `HiveRepository` at `lib/main.dart:51`.
- ~12 consumer call sites (`ref.watch` / `ref.read` / `ref.listen`) across:
  - `lib/ui/home_page.dart` (8 sites — initState, listen, watch, plus action callbacks)
  - `lib/ui/list_page.dart` (1)
  - `lib/ui/add_list_sheet.dart` (1)
  - `lib/ui/todo_tile.dart` (1, plus methods called on a captured notifier reference)
- One test file: `test/app_state_test.dart` instantiates `AppStateNotifier` directly with a `_FakeRepo`; will need to switch to a `ProviderContainer` with `repoProvider` overridden.
- **Zero** `FutureProvider` / `StreamProvider` / `AsyncValue` / family / `.select` usage. Nothing async to rework.

**Concrete steps (sketch, not a contract):**

1. Bump `flutter_riverpod` to `^3.x`. Add `riverpod_annotation`, `riverpod_generator`, `build_runner` (dev).
2. Introduce a `repoProvider` for `HiveRepository` (overridable). Codegen providers can't take an `overrideWith` lambda the same way `StateNotifierProvider` does, so the seeded-repo pattern moves to overriding a separate dependency provider.
3. Convert `AppStateNotifier` → `@riverpod class AppState extends _$AppState`. `build()` reads the repo via `ref.watch(repoProvider)` and returns the initial state.
4. Run `dart run build_runner build` (and document it in the dev workflow).
5. Update consumer sites — the `.notifier` access pattern survives, but the generated provider name and class shape change.
6. Update `test/app_state_test.dart` to use `ProviderContainer` with `repoProvider` overridden to `_FakeRepo`.
7. *Optional follow-up:* replace the manual `_isSubmitting` guard at `lib/ui/add_list_sheet.dart:15` with a Riverpod 3 mutation.
8. Bump `pubspec.yaml` version (0.2.0+2 → 0.3.0+3) and add a CHANGELOG entry; surface "Release — 0.3.0" in the PR description.

**Risk / cost.** ~1–3 hours. Migration guide is well-documented. Main structural change is the `ProviderScope.overrideWith` pattern → separate overridable `repoProvider`. Test rework is small.

**Depends on.** Nothing.

---

<!--
Add new entries below this line. Order is loose — priority is the
signal, not position. When an entry ships, delete it; the CHANGELOG
captures the user-facing record and git history captures the rest.
-->
