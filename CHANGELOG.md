# Changelog

All notable changes to **Glitter List** are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-23

First versioned cut of the app. Local-only multi-list todos with a glittery, offline-first Flutter build for Android and iOS.

### Added

- **Multi-list todos.** Create named lists, swipe between them with a page indicator, reorder items via a drag handle, toggle completion, edit item text in place.
- **Offline-first storage** with Hive (community fork `hive_ce`): every change persists to disk immediately; lists survive app restarts, no network calls anywhere.
- **Custom pink / purple color palette** with automatic light/dark mode support. Light mode: pink scaffold with dark-pink content text; dark mode: deep-purple scaffold with light-purple content text. Hot-pink accent for FAB and checkboxes.
- **Sniglet** as the app typeface, bundled as TTF assets so the app has zero runtime font fetch. Ships fully usable offline on first launch.
- **Check-off animation.** Tapping an item plays four parallel effects over 1 second: a rainbow strikethrough draws across the text, the checkbox glows with a bell-curve burst, ten sparkles emanate outward from the checkbox, and the item text crossfades to its muted "done" color. Multi-line items draw the strikethrough sequentially per line, with a single rainbow gradient that continues seamlessly across all wrapped lines.
- **Hamburger menu** with enlarged labels and icons: **New List**, **Rename List**, **Clear Completed** (visible only when there's something to clear, with a count-based confirm dialog), **Delete List**.
- **Long list titles wrap.** The AppBar grows vertically to fit titles that exceed one line (up to three).
- **Inline edit.** Tap any item to edit its text; the cursor appears in place with no font size or color shift.
- **Developer error handlers** that capture framework and async exceptions with a `[glitter-error]` log prefix for easy grep.
- **Custom app icon** replacing the default Flutter launcher icon. Single 1254×1254 opaque composite (sparkly pink-purple gradient, notepad + pen + gem) used as the master for both platforms. Android wraps it in a minimal adaptive-icon XML using the composite as the background layer with a transparent foreground — the launcher masks the whole thing to the device's configured shape (circle, squircle, rounded square) without the Android 8+ "legacy bitmap in a white circle" fallback. iOS applies its own rounded-rect mask.

### Fixed

- Dialog `TextEditingController` lifecycle race that tripped Flutter's internal `_dependents.isEmpty` framework assertion when tapping **Cancel** during the dialog's exit animation.
- Default Android FAB contrast on the pink scaffold (it was invisible against the auto-generated pale-pink `primaryContainer`).

### Notes

- iOS builds require macOS + Xcode; they are not producible on the Linux development host. The `ios/` scaffold is kept up to date so the code is iOS-ready when a Mac or a CI macOS runner is wired in.
- Android release signing still uses the `flutter create` debug keystore. A proper release signing config will be set up before the first Play Store submission.
