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

<!-- Add new entries below. Order is loose; priority is the signal. When an entry ships, delete it. -->
