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

# Hoist `BgParallaxScope` above `MaterialApp`

- **Status:** Candidate
- **Priority:** Low
- **Why:** Today `BgParallaxScope` is built inside `_HomePageState.build`, so it sits below `MaterialApp`'s `Navigator` / root `Overlay`. Anything that reparents into the root overlay (modal dialogs, popup-menu surfaces, drag-reorder proxies) loses access to the scope and falls back to `Alignment.center` for any per-line frosted strip rendered there. We band-aided the drag-reorder case with `proxyDecorator` re-publishing the scope; modal route content currently shows opaque chrome from `ColorScheme.surface`, so the scope absence isn't *visibly* wrong there yet, but any future widget that wants to show frosted strips inside an overlay would hit the same corner.
- **Scope:** Lift the scope into a small `StatefulWidget` wrapper around `GlitterListApp` (or above `MaterialApp` inside it) and pass `_bgListenable` + `Alignment` down via an `InheritedNotifier` keyed on the existing `Listenable.merge`. Move the parallax-state plumbing (`PageController`, `_verticalT`) into the wrapper too, or thread them up.
- **Risk / cost:** ~half day. Touches the bootstrap path; needs care so existing `ProviderScope` overrides (test fakes) still apply.
- **Depends on:** Nothing.

---

# Data persistence / Export / backup mechanism

- **Status:** Candidate
- **Priority:** Medium
- **Why:** Today, every list lives in the Hive box on the device. A reinstall, a lost phone, or a "send my groceries to my partner" moment all fall off the cliff. We need both a backup story (so reinstalls survive) and a share story (so a list can move out of the app).
- **Scope:** Two adjacent capabilities. (1) **Backup / restore** — pick the right transport: JSON file via the OS file picker, iCloud / Google Drive sync, or a local-first sqlite-style export. JSON file is the cheapest first cut and works offline. (2) **Share** — every list serializes to Markdown by design (one `- [ ] item` per line, `# List name` header), so it can paste into iMessage / Mail / Slack / wherever, with or without Glitter List on the receiving end. The share sheet is the system surface; the format is just stringified Markdown.
- **Risk / cost:** ~1 day for JSON file backup + Markdown share. Cloud sync (iCloud/Drive) is a separate, larger track and should be its own entry once we decide we want it.
- **Depends on:** Nothing.

---

<!-- Add new entries below. Order is loose; priority is the signal. When an entry ships, delete it. -->
# Tilt-driven parallax (iOS 7 lineage)

- **Status:** Candidate
- **Priority:** Low
- **Why:** Layer on top of the scroll-driven background parallax — list items shift subtly relative to the background as the device tilts. Same visual lineage as iOS 7 home screen icons.
- **Scope:** `sensors_plus` (or `motion_sensors` for fused attitude). Low-pass-filter accelerometer X/Y to extract the gravity vector, map to a small per-layer translation (a few px). Compose with the existing scroll parallax. Honor `MediaQuery.disableAnimations` (Reduce Motion) — non-optional.
- **Permissions / platforms:** Android — no runtime permission for accel/gyro. iOS — Info.plist needs `NSMotionUsageDescription`; whether a Motion & Fitness prompt actually fires depends on which Core Motion APIs get touched (raw `CMMotionManager` is typically silent; activity/pedometer APIs prompt). Verify on device before shipping. Flutter Web on iOS Safari — explicit `DeviceOrientationEvent.requestPermission()` behind a tap-to-enable. Desktop — no sensors; graceful no-op fallback.
- **Risk / cost:** ~half day. Keep motion subtle; overshoot reads as gimmicky. Battery cost is negligible at typical sample rates.
- **Depends on:** Nothing.

---

# True wide-gamut / HDR for the bg image

- **Status:** Parked — Flutter image pipeline limit
- **Priority:** Low
- **Why:** Saturation matrix on `DecorationImage.colorFilter` is the closest "HDR pop" we can do today in sRGB. Real wide-gamut paths in Flutter (Display P3 colors, HDR10/AVIF source) work for code-defined colors on iOS Impeller but are still patchy for image assets, especially on Android.
- **Scope:** Convert bg PNGs to wide-gamut-tagged AVIF or HEIC; load via `ImageProvider` with explicit color space; verify iOS-Impeller, Android-Impeller, Skia fallback. Also write a `FragmentProgram` blur shader if we want full bake-free real-time blur.
- **Risk / cost:** Days, with platform-specific landmines. Defer until Flutter's wide-gamut image story is documented and stable.
- **Depends on:** Flutter / Impeller maturing on this front.
