## v0.5.2

- fix(macos): tray popover was growing vertically past its configured
  600 px height — on a narrow tray popover it stretched to ~1180 px
  because the Flutter view pushed the NSPopover to fit content.
  Pinning `preferredContentSize = 375×600` on `PopoverContainer-
  ViewController` locks the popover to the intended size.

- fix(home): MagicRings stayed anchored to a stale global offset when
  the window resized (macOS desktop / orientation changes). Added
  `WidgetsBindingObserver.didChangeMetrics` to `_ConnectCircle` so the
  ring origin is re-reported after the layout settles post-resize.

## v0.5.1

- feat(about): full game-feel pass on the File Transfer easter egg.

  - Friction mechanic #1 — WANDERING TARGET: the `shipped/` drop zone
    drifts in a Lissajous-like path with the amplitude (×1.6) and
    frequency (×1.8) jumping the moment a card is picked up. The target
    actively flees while you aim.
  - Friction mechanic #2 — SHRINKING TARGET: when idle the drop zone
    fills the available height (reads as "obvious target"), but the
    moment a drag starts it animates down to a 220-dp square in the
    centre (`AnimatedContainer`, 280 ms ease-out-cubic). The surrounding
    empty space becomes a miss zone.
  - Friction mechanic #3 — ANTI-DRAG PINGS: speech-bubble taunts cycle
    every 1.1 s while dragging ("куда?", "не туда", "точно?", …). The
    kinvsh card switches to an escalating dread set ("НЕТ", "умоляю",
    "это конец").
  - Success polish: animated progress bar (350 ms), 14-particle confetti
    via `CustomPainter`, drop-zone pulse (1.0→1.08→1.0), "+1 shipped"
    float-up, medium haptic.
  - Failure polish: releasing outside the target triggers a heavy haptic
    and a shard burst via the same painter with a muted grey palette +
    slimmer rectangles, originating at the global drop point.
  - Surprise A — CHEN BOOMERANG: chen08209's first "successful" drop is
    a fakeout. The card pops back out with a red "не так быстро /
    chen08209 вернулся" banner, progress rolls back to 0, you drop him
    again. Triggers once. The joke is you think the game glitched.
  - Surprise B — KINVSH GHOST COUNTER: while kinvsh is hovering the
    drop zone, the "Перенеси 9 из 9" counter cycles through nonsense
    frames ("9 из 13" → "9 из ∞" → "? из ?"). Pure typographic dread.
  - Surprise C — KINVSH GLITCH EXIT: instead of a calm "connection lost"
    screen, dropping kinvsh fires a 4-flash black/red sequence
    (~120 ms each, heavy haptic on each) followed by a fake terminal
    stack trace ("kernel panic: unexpected contributor") before the app
    actually calls `handleExit()`. Total ~1.5 s of drama before exit.

- fix(game): `AnimatedContainer` between `double.infinity` and a finite
  number crashed with "Cannot interpolate between finite and unbounded
  constraints" (box.dart:495). Wrapped the drop zone in `LayoutBuilder`
  and animate between two resolved finite numbers instead. Added a
  fallback (360/480) for the first layout pass when the parent can be
  unbounded.

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

- fix(about): restore missing icon.png

  The logo asset was accidentally removed in `61fe7c0` ("remove unused
  legacy brand assets") but still referenced by the About page,
  sidebar, and launcher icon config. Restored from git history.

- refactor(about): clean up the About page

  Dropped the three separate "contributors / thanks / gratitude"
  sections inherited from upstream forks. Public About is now lean:
  logo + name + version + core + description + `Based on FlClashX` +
  a single "Благодарность" menu entry that opens a credits sheet.

  Removed in-app "Check for updates" on Android (Play Store policy
  forbids it — updates go through the store channel). Retained for
  desktop builds.

  Fixed stale repo links: `Оригинальный репозиторий` now points to
  pluralplay/FlClashX (our direct upstream, not chen08209/FlClash),
  `Ядро` points to MetaCubeX/mihomo (the actual VPN engine).

- feat(about): 3D flip on dropweb header

  Tap the logo + name block to flip it 180° — the front shows the
  dropweb icon and name/version, the back shows the author's avatar
  and `kinvsh`. Tap again to flip back. Subtle vanity, nothing more.

- feat(about): File Transfer drag-and-drop easter egg

  Ten taps on the header open a game: drag each contributor card from
  `contributors/` into `shipped/`, in credits order (chen08209 →
  pluralplay → ... → kinvsh). The last card (kinvsh) closes the app
  on drop via `appController.handleExit()`. You literally can't finish
  shipping yourself.

  Added avatars: `chen08209.jpg`, `enkinvsh.jpg` (GitHub).

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
