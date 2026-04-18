## v0.5.0

- perf: fix Dashboard → Settings transition stutter

  Root cause: `_TvItem` in `lib/views/tools.dart` triggered a Keystore
  IPC call (`preferences.getProfileUrl`) via `unawaited()` on every
  ToolsView `build()`. During a page transition the home state cascade
  rebuilt ToolsView several times back-to-back, blocking the UI thread
  on repeated Keystore reads.

  Fix: move the profile-URL fetch from `build()` into `initState()`
  via `ref.listenManual(currentProfileProvider, ...)`, so the IPC
  fires only when the profile actually changes.

  Measured on Pixel 10 (SurfaceFlinger --latency, debug build):

  |          | before | after |
  |----------|--------|-------|
  | p50      |   9 ms |  8 ms |
  | p95      |  55 ms | 11 ms |
  | p99      | 335 ms | 15 ms |
  | slow (>12ms) | 19% |  6%  |

  The 335ms single-frame spike on first transition is gone.

- refactor(about): clean up the About page

  Dropped the three separate "contributors / thanks / gratitude"
  sections inherited from upstream forks. Public About now shows only
  logo, version, core version, description, `Based on FlClashX` line,
  and links (Project / FlClashX / mihomo core).

  Removed in-app "Check for updates" on Android (Play Store policy
  forbids it — updates go through the store channel). Retained for
  desktop builds.

  Dropped stale repo links: original FlClash chen08209 link replaced
  by pluralplay/FlClashX (our direct upstream), core link now points
  to MetaCubeX/mihomo (the actual VPN engine).

- feat(about): hidden credits via File Transfer Manager easter egg

  Ten taps on the About logo open a fake "File Transfer Manager" that
  transfers nine "files" — each file is actually a contributor, shown
  with avatar and role. Order is the credits roll:
  chen08209 → pluralplay → kastov → x_kit_ → katsukibtw →
  cool_coala → arpic → legiz → enkinvsh.

  The transfer never finishes on the last one — progress hangs
  forever at ~87%. The joke is the punchline.

  Added avatars: `chen08209.jpg`, `enkinvsh.jpg` (from GitHub).

## v0.4.5

- fix(fatal): resolve splash hang on cold start / post-reboot

  Root cause: `lib/common/file_logger.dart` used `DateFormat('yyyy-MM-dd')`
  without an explicit locale. During early cold start (before
  `Intl.systemLocale` is loaded), `intl_helpers.verifiedLocale` throws.
  `_processQueue` caught the error silently and recursively re-scheduled
  itself via `unawaited(_processQueue())`. Every queued log message
  re-triggered the same throw, producing an infinite microtask loop that
  starved the event loop — so `runApp`'s widget mount never fired and
  the splash screen sat on `DRAW_PENDING` forever.

  Most visible after reboot (the service isolate floods logs before the
  main isolate schedules its first frame), but the bug was fundamentally
  a time-of-check / locale-availability race, independent of device.

  Fix:
  - Replace `DateFormat` with manual ISO formatting in `_getTodayDate`
    and `_getTimestamp`. No locale dependency.
  - Drop the write queue on sink failure instead of retrying a broken
    sink — infinite retry on persistent errors is never correct.

  Diagnosed via Dart VM service `getStack` on a live hung debug build.

- security: move subscription URLs to flutter_secure_storage
- security: harden Dart + Android surface for Play submission
- perf: cache Theme.of() + debounce sticky-header scroll updates
- fix(android): FAB now reacts when VPN is stopped from outside the app
- fix(android): bump minSdk to 24 for flutter_secure_storage v10
- fix(android): suppress R8 warnings for unused Play Core / tika classes
- fix(android): restore bottom-right ambient glow on splash

## v0.4.4

- fix(ci): add write permissions for changelog job

## v0.4.3

- fix(android): restore minSdk 23 (required by core module)

## v0.4.2

- feat(windows): unified tray icon - black bg, gray db when inactive

## v0.4.1

- chore: use flutter SDK minSdkVersion, update fork refs

- perf: optimize UI for mid-range devices (Pixel 5)

- - disable BackdropFilter blur on navbar, connect button, subscription tabs
- - disable ColorBendsBg shader (reloads on every rebuild)
- - enable keep: true for dashboard/tools pages to avoid rebuild on switch
- - add AutomaticKeepAliveClientMixin for Proxies/Profiles tabs

- Fixes 12fps lag on swipes and page transitions on Snapdragon 765G.

- docs: improve README - stars badge, SEO alt texts, sync EN version

- docs: remove build instructions

- docs: add dropweb.org link

- docs: add trending AI keywords

- docs: add disclaimer with SEO keywords

- docs: clean up README, restore header

# Changelog

## v0.4.0

- Улучшена стабильность и безопасность соединения

## v0.3.4

- feat(ui): remove Direct mode, auto-select fastest proxy for Global
- feat(android): add home screen VPN toggle widget with Lumina styling
- feat(ux): hide navbar when no profile — onboarding-ready first launch
- feat(ux): add profile bottom sheet with QR/URL + glow pulse when no profile
- feat(ui): rework navbar — oval glass pill selector, dual icons, compact layout
- refactor(ui): use theme colors for mesh background instead of hardcoded Lumina
- fix(android): bump minSdk to 23 to match core module
- fix(ci): await Windows/Linux build, clean release layout
