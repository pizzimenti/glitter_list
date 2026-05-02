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

# UI cycle: tilt parallax → multi-depth frosted overlays → HDR sparkle dust

- **Status:** Next-up
- **Priority:** High
- **Why:** The app's identity is "glittery." Today's scroll-driven bg parallax is the floor of that vision; device-tilt parallax, multi-depth frosted overlays, and HDR-bright sparkle dust are the ceiling. The three phases compose into one design — shipping any in isolation under-delivers the look. Each phase is a separate PR; the cycle isn't "done" until all three land.

## Phase 1 — Tilt-driven parallax (single layer)

- **Scope:** Layer device tilt on top of the existing scroll-driven bg parallax. Single layer (the bg image) only at this stage — multi-layer comes in Phase 2. `sensors_plus` (or `motion_sensors` for fused attitude). Low-pass-filter accel X/Y to extract the gravity vector, map to a small per-axis translation (a few px on top of the current scroll-driven `Alignment`). Compose additively with the existing scroll parallax. Honor `MediaQuery.disableAnimations` (Reduce Motion) — non-optional, no escape hatch.
- **User-facing "new motion" on/off slider (always visible):** small slider/switch sitting at the top of the app — likely just below the AppBar, persistent across all lists, present even on the empty-lists fallback. Defaults to ON. Track fill is a rainbow gradient when on (same lineage as `RainbowStrikethrough` — cycle through the spectrum, optionally subtly animated); muted/desaturated when off. **Scope of the gate is narrow.** The slider only governs the *new* motion effects introduced by this UI cycle: tilt-driven parallax (Phase 1) and HDR sparkle dust (Phase 3). The existing scroll- and swipe-driven background parallax stays on regardless of slider position — that's load-bearing app feel and not on the table. Persisted in Hive (separate key from the per-list data so a `clearLists` doesn't wipe it). When `MediaQuery.disableAnimations` is true, the slider is force-OFF AND non-interactive (greyed) — OS Reduce Motion takes precedence and the user can't override it back on. (Reduce Motion is a *broader* gate than the slider: it also kills tile sparkles, glitter outlines, and other in-cell animations; the slider doesn't touch those.)
- **Tilt-physics emulator tests:** new integration test file `integration_test/tilt_parallax_test.dart`. Drive synthetic tilt via `adb emu sensor set acceleration <x> <y> <z>` against the running emulator, then assert the bg image's `Alignment` (read off `BgParallaxScope`) shifts by the expected amount given the chosen coefficients. Verifies the *physics* — coefficient → output mapping — not just that the input plumbing wires up. Each chosen coefficient gets its own assertion (e.g. tilt of 0.5g on X should produce ~3 px additional horizontal pan at the documented multiplier; resting at 0g should yield only the scroll/swipe-driven `Alignment` with no tilt contribution). Phase 2 extends this same harness to assert per-depth differential. Also add a "slider OFF" assertion — tilt with the slider toggled off must NOT shift alignment beyond the scroll/swipe baseline (proving the slider's narrow scope: scroll/swipe parallax remains, tilt contribution is gone).
- **Permissions / platforms:** Android — no runtime permission for accel/gyro. iOS — Info.plist needs `NSMotionUsageDescription`; whether a Motion & Fitness system prompt actually fires depends on which Core Motion APIs get touched (raw `CMMotionManager` is typically silent; activity/pedometer APIs prompt). Verify on device before shipping. Flutter Web on iOS Safari — explicit `DeviceOrientationEvent.requestPermission()` behind a tap-to-enable. Desktop — no sensors; graceful no-op fallback.
- **Risk / cost:** ~1 day (was ~half day before the toggle + emulator-tilt tests landed in scope). Keep motion subtle (a few px max); overshoot reads as gimmicky. Battery cost is negligible at typical sample rates (~30 Hz with low-pass filtering).
- **Depends on:** Hoisted `BgParallaxScope` (the wrapper above `MaterialApp` introduced in 0.6.1) so Phase 2 has a clean home for per-component depths.

## Phase 2 — Multi-depth frosted-glass overlays

- **Scope:** Apply frosted glass to **every** overlay surface — AppBar's `PopupMenuButton`, the long-press item menu, every `showDialog` chrome (Rename, Delete confirm, Clear Completed, New Item), and `AddListSheet`. Each surface picks a depth from a small palette (illustrative starting values: `bg=0.0, AppBar=0.4, popup=0.7, dialog=1.0`). Higher depth = more apparent closeness to the viewer = larger tilt response, creating a parallax differential between layers.
- **Inside each popup / dialog / sheet:** single rounded-rect frosted backdrop (one `PreBakedBackdrop` chrome per surface), sharp text and icons on top. Not per-line strips — `PerLineBackdropBlur` stays for the AppBar title where it earned its keep; popup contents are flatter and simpler.
- **Tilt behavior while an overlay is open:** every layer continues to respond to tilt — bg, overlay chrome, and overlay content all shift via their depth multipliers. Foreground layers move more than the bg; net effect reads as parallax depth, not as the world freezing when a menu is up.
- **Plumbing changes the existing scope:** `BgParallaxScope` today publishes one `Alignment`. Phase 2 needs either (a) raw scroll + tilt inputs published, with each consumer applying its own depth multiplier at paint time, or (b) a `BgParallaxScope.alignmentFor(depth)` lookup. (a) is the more iOS-7-faithful model; (b) is fewer call sites to update. Decide during the Phase 2 plan.
- **Other UI changes that ride along:** the `showDialog` chrome currently uses Material's default modal scrim — frosting changes the read of "this is modal." Tune the scrim opacity (or remove it in favor of the frost itself signaling modality). `AddListSheet` already has its own bottom-sheet visual; check that frosting reads with the existing rounded top corners and drag handle.
- **Tilt-physics tests extended:** `integration_test/tilt_parallax_test.dart` (introduced in Phase 1) gains per-depth assertions — for each depth in the palette, drive a synthetic tilt and verify the surface at that depth shifts by `tilt × depth_multiplier` (within a small tolerance for low-pass filter lag). Catches accidental "all layers move identically" regressions where the depth lookup mis-resolves and the differential collapses.
- **Risk / cost:** ~1.5–2 days. Trickiest: tuning depth multipliers so motion reads as alive, not as nauseating. Build the palette as `--dart-define`-tunable knobs during dev so the visual sweet spot can be dialed in on a real device.
- **Depends on:** Phase 1 (tilt input plumbing + the parallax on/off slider + the tilt-physics test harness).

## Phase 3 — HDR sparkle dust (tilt-activated)

- **Scope:** Procedural particle effect (no image source). Sparkles spawn at a rate that ramps with **tilt magnitude** — sparkles "scatter" as the device moves, idle when it's flat. Particles render as small bright pinpoints with a bloom halo. On HDR paths, particle linear color values exceed `1.0` and trigger true HDR display brightness; on non-HDR paths, they render at sRGB max — still visible, just less impressive.
- **Per-platform HDR feasibility (asymmetric quality is acceptable; the design degrades gracefully):**
  - **iOS / Impeller:** **viable.** Display P3 wide-gamut works for code-defined colors today. Procedural sparkles don't need HDR10 image source — they're shader-generated. Bloom via `FragmentProgram`. iOS Impeller is the most stable wide-gamut path Flutter has.
  - **Android / Impeller:** **partial.** Wide-gamut surface backing requires Vulkan + API 33+. On older devices and on the GLES fallback, sparkles render at bright sRGB. Verify on the API 34 CI emulator and on at least one real device with an HDR-capable display (Pixel 7+, recent Samsung) before claiming HDR works on Android.
  - **Web / CanvasKit:** **not viable today.** CanvasKit's 2D canvas doesn't expose an HDR / wide-gamut path. CSS `color(display-p3 …)` works in modern browsers but Flutter Web doesn't pipe canvas content through that. Sparkles render at bright sRGB; revisit when Flutter Web ships WebGPU or a wide-gamut canvas backend (likely 2027+).
- **The deliverable includes the per-platform probe.** "HDR works" is asserted, not assumed — test on one HDR-capable device per platform before declaring shipped, capture a same-frame screenshot from each, eyeball the difference vs sRGB fallback. If the difference is invisible on a given platform, ship the sRGB fallback there and note it in the changelog.
- **Risk / cost:** ~1 day for the particle system + tilt-activation logic. Add ~half day for the bloom `FragmentProgram` and the per-platform wide-gamut probing pass. Real risk is "HDR works on iOS, useless on Android, useless on Web" — that's an acceptable outcome; just don't pretend it works everywhere.
- **Depends on:** Phase 1 (tilt magnitude is the activation signal).

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
