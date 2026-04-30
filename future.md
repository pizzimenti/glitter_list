# Future work

A scratchpad of candidate work for Glitter List. **Not a commitment.** Items get added, reordered, shipped, or dropped without ceremony — priority shifts as the project does. When something ships, delete its entry; `CHANGELOG.md` and git history are the archive.

Order is loose; priority is the signal, not position.

Each entry uses these fields:

- **Status** — `Candidate`, `Next-up`, or `Parked` (with reason)
- **Priority** — `High` / `Medium` / `Low`, gut feel
- **Why** — the motivation
- **Scope** — what's involved, roughly
- **Risk / cost** — effort + what could go sideways
- **Depends on** — gating items, if any

Extra fields (e.g. permissions, accessibility, platform notes) are fine to add per entry where they materially affect the call.

---

# Migrate to Riverpod 3 (with codegen)

- **Status:** Candidate
- **Priority:** Medium
- **Why:** Scaffold pulled `flutter_riverpod ^2.5.1` by inertia; Riverpod 3 + `@riverpod` codegen is the modern idiom and cuts boilerplate. Cheaper now than later, while the provider surface is small.
- **Scope:** Single `StateNotifierProvider` (`appStateProvider`), one notifier, a handful of consumer sites, one `ProviderScope` override, one test. No async providers, families, or `.select` in play.
- **Risk / cost:** ~1–3 hours. Main shift: the seeded-repo `ProviderScope.overrideWith` becomes a separate overridable dependency provider, since codegen providers don't take a build-arg override the same way.
- **Depends on:** Nothing.

---

# Tilt-driven parallax (iOS 7 lineage)

- **Status:** Candidate
- **Priority:** Low
- **Why:** Layer on top of the scroll-driven background parallax — list items shift subtly relative to the background as the device tilts. Same visual lineage as iOS 7 home screen icons.
- **Scope:** `sensors_plus` (or `motion_sensors` for fused attitude). Low-pass-filter accelerometer X/Y to extract the gravity vector, map to a small per-layer translation (a few px). Compose with the existing scroll parallax. Honor `MediaQuery.disableAnimations` (Reduce Motion) — non-optional.
- **Permissions / platforms:** Android — no runtime permission for accel/gyro. iOS — Info.plist needs `NSMotionUsageDescription`; whether a Motion & Fitness prompt actually fires depends on which Core Motion APIs get touched (raw `CMMotionManager` is typically silent; activity/pedometer APIs prompt). Verify on device before shipping. Flutter Web on iOS Safari — explicit `DeviceOrientationEvent.requestPermission()` behind a tap-to-enable. Desktop — no sensors; graceful no-op fallback.
- **Risk / cost:** ~half day. Keep motion subtle; overshoot reads as gimmicky. Battery cost is negligible at typical sample rates.
- **Depends on:** Nothing.

---

# Hoist `BgParallaxScope` above `MaterialApp`

- **Status:** Candidate
- **Priority:** Low
- **Why:** Today `BgParallaxScope` is built inside `_HomePageState.build`, so it sits below `MaterialApp`'s `Navigator` / root `Overlay`. Anything that reparents into the root overlay (modal dialogs, popup-menu surfaces, drag-reorder proxies) loses access to the scope and falls back to `Alignment.center` for any per-line frosted strip rendered there. We band-aided the drag-reorder case with `proxyDecorator` re-publishing the scope; modal route content currently shows opaque chrome from `ColorScheme.surface`, so the scope absence isn't *visibly* wrong there yet, but any future widget that wants to show frosted strips inside an overlay would hit the same corner.
- **Scope:** Lift the scope into a small `StatefulWidget` wrapper around `GlitterListApp` (or above `MaterialApp` inside it) and pass `_bgListenable` + `Alignment` down via an `InheritedNotifier` keyed on the existing `Listenable.merge`. Move the parallax-state plumbing (`PageController`, `_verticalT`) into the wrapper too, or thread them up.
- **Risk / cost:** ~half day. Touches the bootstrap path; needs care so existing `ProviderScope` overrides (test fakes) still apply.
- **Depends on:** Nothing.

---

# True wide-gamut / HDR for the bg image

- **Status:** Parked — Flutter image pipeline limit
- **Priority:** Low
- **Why:** Saturation matrix on `DecorationImage.colorFilter` is the closest "HDR pop" we can do today in sRGB. Real wide-gamut paths in Flutter (Display P3 colors, HDR10/AVIF source) work for code-defined colors on iOS Impeller but are still patchy for image assets, especially on Android.
- **Scope:** Convert bg PNGs to wide-gamut-tagged AVIF or HEIC; load via `ImageProvider` with explicit color space; verify iOS-Impeller, Android-Impeller, Skia fallback. Also write a `FragmentProgram` blur shader if we want full bake-free real-time blur.
- **Risk / cost:** Days, with platform-specific landmines. Defer until Flutter's wide-gamut image story is documented and stable.
- **Depends on:** Flutter / Impeller maturing on this front.

---

<!-- Add new entries below. Order is loose; priority is the signal. When an entry ships, delete it. -->
# export/backup mechanism
** user may need to reinstall the app and get their lists back. json? icloud backup? local db? also, lists should inherantly be stored as markdown on export. we need a way to export a list for email or to share with someone over text who may or may not have Glitter List on their phone.