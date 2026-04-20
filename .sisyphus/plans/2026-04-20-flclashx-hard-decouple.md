# FlClashX Hard Decouple — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate every runtime entanglement between dropweb and FlClashX on Windows. No more deep-link handler hijack. No more `flclashx-*` HTTP header protocol. After this plan, dropweb and FlClashX can coexist on the same machine with zero interference.

**Architecture:** Six sequential waves. Wave 1 fixes the critical Windows registry hijack (Bug #2 root cause). Wave 2 fixes the disappearing connect button on desktop (Bug #1). Wave 3 renames the Remnawave subscription header protocol from `flclashx-*` to `dropweb-*` across 20+ call sites. Wave 4 cleans up Inno Setup uninstaller. Wave 5 finishes Android resource naming cleanup. Wave 6 verifies end-to-end on Windows + Android.

**Tech Stack:** Flutter/Dart (UI + business logic), Kotlin (Android), Inno Setup (Windows installer), `win32_registry` package (registry writes), `window_manager` package (desktop window constraints).

**Decision Record (why this overrides the previous rebrand plan):**

The previous rebrand plan (`.sisyphus/plans/dropweb-full-rebrand.md`, lines 24-27) explicitly marked these as "DO NOT TOUCH":
- `flclashx-*` HTTP headers — kept for Remnawave protocol compat
- `clash://`, `clashmeta://`, `flclash://` URL schemes — kept for client compat

**Reversal rationale (user decision, 2026-04-20):** dropweb is still in closed test group (not yet distributed to real users). User controls both backend (Remnawave panel + `@dropwebpay_bot`) and client. Hard switch is cheap NOW (one-time coordinated update of panel + bot + client). If we wait until public release, hard switch becomes expensive (legacy support forever). The "never crossed paths" property is worth more than backward compat with nobody.

**Coordination contract:**
After Wave 3 merges, the following MUST be updated within the same release window:
- `@dropwebpay_bot` → emit `dropweb://install-config?url=...` links (replace `flclash://...`)
- Remnawave panel template in `cab.dropweb.space` → emit `dropweb-widgets`, `dropweb-hex`, `dropweb-servicename`, `dropweb-servicelogo`, `dropweb-serverinfo`, `dropweb-view`, `dropweb-settings`, `dropweb-hex`, `dropweb-background`, `dropweb-globalmode`, `dropweb-custom` HTTP response headers (replace `flclashx-*`)

**CRITICAL — DO NOT TOUCH in this plan:**
- `libclash/` Go code — this is the embedded mihomo core, not our concern for this bug pair
- `chen08209` / `pluralplay` attribution in `lib/views/about.dart` — legally required by GPL-3.0, a separate branding-polish task if needed
- `CHANGELOG.md` historical entries — those are immutable history
- `docs/plans/2026-04-15-flclashx-port.md` — that's a port plan, different scope
- The `clash.meta` / `clashx.meta` / `clashx` / `clash` core binary name referenced in `lib/common/constant.dart:13` (`coreName = "clashx.meta"`) — this is the mihomo core filename convention, unrelated to our two bugs

---

## Wave 1: Deep-Link Registry Hijack Fix (Bug #2 Core)

**Owner:** Agent A
**Risk:** Medium — writes to Windows registry, must not break FlClashX for users who still use it
**Verification:** `flutter_analyze` clean. Manual: install dropweb alongside FlClashX, confirm `flclash://` still opens FlClashX after dropweb launch.

### Task 1.1: Add `onlyIfMissing` flag to Protocol.register()

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/common/protocol.dart`

**Context:** Currently `Protocol.register(scheme)` unconditionally overwrites `HKCU\Software\Classes\<scheme>\shell\open\command`. We need it to optionally skip registration when the key already exists and points to a different executable.

**Step 1: Open `lib/common/protocol.dart` and verify current state matches lines 1-32 below:**

```dart
import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

class Protocol {

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  Protocol._internal();
  static Protocol? _instance;

  void register(String scheme) {
    final protocolRegKey = 'Software\\Classes\\$scheme';
    const protocolRegValue = RegistryValue.string(
      'URL Protocol',
      '',
    );
    const protocolCmdRegKey = r'shell\open\command';
    final protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }
}

final protocol = Protocol();
```

**Step 2: Replace the file contents with:**

```dart
import 'dart:io';

import 'package:dropweb/common/print.dart';
import 'package:win32_registry/win32_registry.dart';

class Protocol {
  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  Protocol._internal();
  static Protocol? _instance;

  /// Registers a Windows URL protocol handler at
  /// `HKCU\Software\Classes\<scheme>\shell\open\command` pointing to this exe.
  ///
  /// When [onlyIfMissing] is true, the call is a no-op if another application
  /// has already claimed the scheme. This is critical for schemes shared
  /// across forks (e.g. `flclash://`) — we must not hijack a handler that
  /// another client legitimately owns. Detection is by reading the existing
  /// command string and checking it doesn't already point to our own exe.
  void register(String scheme, {bool onlyIfMissing = false}) {
    final protocolRegKey = 'Software\\Classes\\$scheme';

    if (onlyIfMissing && _isAlreadyClaimedByOther(protocolRegKey)) {
      commonPrint.log(
        'Protocol.register: skipping "$scheme://" — already claimed by another app',
      );
      return;
    }

    const protocolRegValue = RegistryValue.string('URL Protocol', '');
    const protocolCmdRegKey = r'shell\open\command';
    final protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }

  /// Returns true if the scheme's `shell\open\command` key exists and points
  /// to an executable that is NOT our own [Platform.resolvedExecutable].
  /// Returns false if the key is missing, unreadable, or already points to us
  /// (in which case overwriting is a no-op anyway).
  bool _isAlreadyClaimedByOther(String protocolRegKey) {
    try {
      // win32_registry 2.1.0 API: Registry.openPath is a static method on
      // Registry (NOT an instance method on RegistryKey). Default access
      // rights are readOnly, so no named arg is needed.
      final cmdKey = Registry.openPath(
        RegistryHive.currentUser,
        path: '$protocolRegKey\\shell\\open\\command',
      );
      final existingCmd = cmdKey.getStringValue('');
      cmdKey.close();
      if (existingCmd == null || existingCmd.isEmpty) return false;
      final ourExe = Platform.resolvedExecutable.toLowerCase();
      return !existingCmd.toLowerCase().contains(ourExe);
    } catch (_) {
      // Key doesn't exist or can't be read — treat as unclaimed.
      return false;
    }
  }

  /// Deletes our own handler for the given scheme, if and only if it currently
  /// points to this exe. Used during app-level cleanup and uninstall paths to
  /// avoid leaving a broken registry entry that points to a deleted binary.
  void unregisterIfOurs(String scheme) {
    final protocolRegKey = 'Software\\Classes\\$scheme';
    try {
      // See note in _isAlreadyClaimedByOther about the win32_registry API.
      final cmdKey = Registry.openPath(
        RegistryHive.currentUser,
        path: '$protocolRegKey\\shell\\open\\command',
      );
      final existingCmd = cmdKey.getStringValue('');
      cmdKey.close();
      if (existingCmd == null) return;
      final ourExe = Platform.resolvedExecutable.toLowerCase();
      if (existingCmd.toLowerCase().contains(ourExe)) {
        Registry.currentUser.deleteKey(protocolRegKey, recursive: true);
        commonPrint.log('Protocol.unregisterIfOurs: removed "$scheme://"');
      }
    } catch (_) {
      // Nothing to delete.
    }
  }
}

final protocol = Protocol();
```

**Step 3: Verify the API surface — run `flutter_analyze`:**

Expected: 0 errors. Any warnings about `deleteKey` or `openPath` signatures → stop and cross-check against `win32_registry ^2.1.0` API (package pinned at `pubspec.lock:1686-1693`). Key API facts for 2.1.0: `Registry.openPath(hive, path: ..., desiredAccessRights: ...)` is a static method on `Registry`, not an instance method on `RegistryKey`. `Registry.currentUser.deleteKey(name, recursive: true)` IS an instance method and is correct as written.

**Step 4: Commit**

```bash
git add lib/common/protocol.dart
git commit -m "feat(windows): add onlyIfMissing + unregisterIfOurs to Protocol

Preparing to stop hijacking flclash:// and clashx:// deep-link handlers
that legitimately belong to other apps. The new flag lets us claim a
scheme only when it's unclaimed, and the new method lets us clean up
our own claims without touching other apps' claims."
```

---

### Task 1.2: Migrate existing hijacked registry entries + stop new hijacks

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/common/window.dart`

**Context:** Current `window.dart` lines 16-20 unconditionally register `clashx`, `flclash`, `dropweb` every launch. We need to (a) run a one-time cleanup of hijacked `flclash://` and `clashx://` entries that already point to our exe from previous installs, and (b) switch registration to `onlyIfMissing` mode going forward.

**Step 1: Open `lib/common/window.dart` and locate the current block at lines 16-20:**

```dart
    if (Platform.isWindows) {
      protocol.register("clashx");
      protocol.register("flclash");
      protocol.register("dropweb");
    }
```

**Step 2: Replace that block with:**

```dart
    if (Platform.isWindows) {
      // One-time cleanup for users who were running a previous dropweb build
      // that unconditionally overwrote flclash:// and clashx:// handlers.
      // If the current handler still points to our exe, remove it so the
      // scheme becomes unclaimed — letting FlClashX (or any other app) take
      // it back on its next launch. No-op if the handler points elsewhere.
      await _migrateHijackedSchemes();

      // Always claim our own scheme.
      protocol.register("dropweb");

      // Claim common schemes only if no other app currently owns them.
      // This lets users without FlClashX still open flclash:// links in
      // dropweb, while leaving FlClashX-owned handlers untouched.
      protocol.register("flclash", onlyIfMissing: true);
      protocol.register("clashx", onlyIfMissing: true);
    }
```

**Step 3: Add the `_migrateHijackedSchemes()` helper at the bottom of the `Window` class, just before the closing brace. Locate the end of the class (around line 96-97 in the current file) and insert before `}` that closes `class Window`:**

```dart
  static const _migrationPrefKey = 'windows_protocol_cleanup_v1';

  /// Runs once per install. Removes our own claims on flclash:// and clashx://
  /// so [Protocol.register(..., onlyIfMissing: true)] can see them as free.
  /// Guarded by a SharedPreferences flag so repeated launches don't churn the
  /// registry. Safe to call on every launch.
  Future<void> _migrateHijackedSchemes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationPrefKey) == true) return;
      protocol.unregisterIfOurs('flclash');
      protocol.unregisterIfOurs('clashx');
      await prefs.setBool(_migrationPrefKey, true);
    } catch (_) {
      // Migration is best-effort. A failure here just means the user keeps
      // the hijacked handler — they can reinstall to retry. Do not crash.
    }
  }
```

**Step 4: Ensure the SharedPreferences import exists at the top of the file. Current imports are at lines 1-7:**

```dart
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
```

Add after line 7:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

**Step 5: Run `flutter_analyze`**

Expected: 0 errors. If warnings appear about `unregisterIfOurs` not found → you skipped Task 1.1; go back and complete it first.

**Step 6: Commit**

```bash
git add lib/common/window.dart
git commit -m "fix(windows): stop hijacking flclash:// and clashx:// handlers

Previous behavior unconditionally overwrote HKCU\\Software\\Classes\\flclash
and \\clashx on every launch, stealing those schemes from FlClashX even for
users who already had it installed. That caused users with both apps to see
dropweb open when they clicked subscription links in Telegram bots meant
for FlClashX — dropweb then loaded the subscription + applied the server's
flclashx-* HTTP headers, making it look like dropweb was reading FlClashX
data from disk when in fact it was a deep-link interception bug.

Now:
- dropweb:// always claimed (our own scheme)
- flclash://, clashx:// claimed only if no other app owns them
- One-time migration (guarded by windows_protocol_cleanup_v1 pref) removes
  our existing claims on those shared schemes so FlClashX reclaims them on
  its next launch.

Fixes Bug #2: 'dropweb pulls FlClashX subscriptions + widgets'."
```

---

## Wave 2: Desktop Connect-Button Visibility Fix (Bug #1)

**Owner:** Agent A
**Risk:** Low — window sizing change only
**Verification:** `flutter_analyze` clean. Manual on Windows: cannot drag window wider than 600px; connect button always visible.

### Task 2.1: Lock desktop window width to mobile viewport

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/common/window.dart`

**Context:** The dashboard connect button (`lib/views/dashboard/widgets/start_button.dart`) is only rendered when `viewMode == ViewMode.mobile` (`lib/pages/home.dart:40-44`). The breakpoint in `lib/common/constant.dart:53` switches to laptop layout at 600px, but the laptop/desktop layout has no connect button. Simplest correct fix: prevent the window from ever being wider than the mobile breakpoint. This keeps dropweb as a "compact utility window" on desktop — which is the actual design intent given the mobile-first layout.

**Step 1: Open `lib/common/window.dart`. Locate the `WindowOptions` construction around lines 27-31:**

```dart
    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: Size(props.width, props.height),
      minimumSize: const Size(380, 400),
    );
```

**Step 2: Replace with:**

```dart
    await windowManager.ensureInitialized();
    // Desktop UI is mobile-first: the connect button, navigation bar, and
    // widget layout are only rendered in ViewMode.mobile (≤ 600px wide, see
    // maxMobileWidth in lib/common/constant.dart). The laptop/desktop
    // layouts in lib/pages/home.dart don't render a connect button, so we
    // must prevent the window from crossing the mobile breakpoint.
    //
    // Width is clamped to 600 (the breakpoint); height is unconstrained so
    // users can make the window as tall as they want.
    final clampedWidth = props.width.clamp(380.0, 600.0);
    final windowOptions = WindowOptions(
      size: Size(clampedWidth, props.height),
      minimumSize: const Size(380, 400),
      maximumSize: const Size(600, 99999),
    );
```

**Step 3: After the `waitUntilReadyToShow` block (currently around lines 64-66), add an explicit `setMaximumSize` call to enforce the constraint on already-created windows. Locate:**

```dart
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
```

**Replace with:**

```dart
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      // Enforce width cap at runtime (waitUntilReadyToShow doesn't always
      // honor maximumSize on Windows if the saved window state is larger).
      await windowManager.setMaximumSize(const Size(600, 99999));
      await windowManager.setMinimumSize(const Size(380, 400));
    });
```

**Step 4: Run `flutter_analyze`**

Expected: 0 errors.

**Step 5: Commit**

```bash
git add lib/common/window.dart
git commit -m "fix(desktop): clamp window width to mobile breakpoint (≤600px)

The dashboard connect button + bottom nav bar are only rendered in
ViewMode.mobile. Desktop/laptop layouts have no connect button at all
(lib/pages/home.dart:40-44 returns null for bottomNavigationBar when
viewMode != mobile). Users on Windows were dragging the window wider,
crossing the maxMobileWidth=600 breakpoint, and losing the only way to
toggle the VPN.

Fix: clamp max width to 600px via window_manager. Height unconstrained.
Saved window state is clamped on restore so existing users aren't stuck
in an oversized window.

Fixes Bug #1: 'connect button disappears when window is stretched wide'."
```

---

## Wave 3: Remnawave Header Protocol Rename `flclashx-*` → `dropweb-*`

**Owner:** Agent A
**Risk:** Medium — breaks subscription compatibility with servers still emitting `flclashx-*`. Acceptable because (a) we're in closed test group, (b) user controls the Remnawave template.
**Verification:** `flutter_analyze` clean. Manual: subscription loaded from Remnawave panel (updated to emit `dropweb-*`) shows custom widgets + theme; subscription with legacy `flclashx-*` headers does NOT apply custom layout (widgets fall back to default).

### Task 3.1: Rename the header prefix parser

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/models/profile.dart`

**Context:** `lib/models/profile.dart:237-241` loops over HTTP response headers and stores any header starting with `flclashx-` into `providerHeaders`. This is the entry point for the whole header-based protocol. Rename the prefix here and the change propagates — the consumers in controller.dart, state.dart, etc. just read from the map with whatever key they expect, so we have to rename their keys too (Tasks 3.2 - 3.6).

**Step 1: Open `lib/models/profile.dart`. Locate lines 237-241:**

```dart
    response.headers.forEach((name, values) {
      if (name.toLowerCase().startsWith('flclashx-') && values.isNotEmpty) {
        providerHeaders[name.toLowerCase()] = values.first;
      }
    });
```

**Step 2: Replace with:**

```dart
    // Subscription providers (Remnawave panel templates) return dropweb-*
    // HTTP headers to customize the dashboard layout, theme, service name,
    // logo, and behavior. Legacy flclashx-* headers from FlClashX-targeted
    // panels are intentionally NOT accepted — dropweb is a distinct product
    // and must not share a customization protocol surface with FlClashX
    // (see .sisyphus/plans/2026-04-20-flclashx-hard-decouple.md for the
    // decision record).
    response.headers.forEach((name, values) {
      if (name.toLowerCase().startsWith('dropweb-') && values.isNotEmpty) {
        providerHeaders[name.toLowerCase()] = values.first;
      }
    });
```

**Step 3: Run `flutter_analyze`**

Expected: 0 errors. The map is still `Map<String, String>`, just with different keys — Dart won't catch the mismatch. We'll fix consumers in the next tasks.

**Step 4: Do NOT commit yet.** Consumers still read `flclashx-*` keys from this map, which will now be empty. Commit after Task 3.6 so the codebase doesn't pass through a broken intermediate state.

---

### Task 3.2: Rename header keys in `lib/controller.dart`

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/controller.dart`

**Context:** 9 call sites read from `providerHeaders['flclashx-*']`. Each must be renamed to `providerHeaders['dropweb-*']`. Confirmed line numbers from grep run during analysis; line numbers may drift ±2 if prior tasks touched the file.

**Step 1: Open `lib/controller.dart` and find each occurrence using this exact grep (run before edits, then re-run after edits to verify 0 remaining):**

```bash
grep -n "flclashx-" lib/controller.dart
```

Expected output before changes (line numbers approximate):

```
104:    final svc = profile.providerHeaders['flclashx-servicename'];
120:    String? groupName = profile.providerHeaders['flclashx-serverinfo'];
292:    final customBehavior = headers['flclashx-custom'];
316:    final settingsHeader = headers['flclashx-settings'];
332:    final hexHeader = headers['flclashx-hex'];
368:          .log('Applying theme from flclashx-hex: #${hexString.toUpperCase()}'
1514:    final dashboardLayout = headers['flclashx-widgets'];
1524:    final proxiesView = headers['flclashx-view'];
```

**Step 2: Replace each `'flclashx-XXX'` string literal with `'dropweb-XXX'`. Do one-at-a-time edits to keep each edit reversible.**

Exact replacements (oldString → newString):

- `profile.providerHeaders['flclashx-servicename']` → `profile.providerHeaders['dropweb-servicename']`
- `profile.providerHeaders['flclashx-serverinfo']` → `profile.providerHeaders['dropweb-serverinfo']`
- `headers['flclashx-custom']` → `headers['dropweb-custom']`
- `headers['flclashx-settings']` → `headers['dropweb-settings']`
- `headers['flclashx-hex']` → `headers['dropweb-hex']`
- `headers['flclashx-widgets']` → `headers['dropweb-widgets']`
- `headers['flclashx-view']` → `headers['dropweb-view']`

For the log line on ~line 368, change `'Applying theme from flclashx-hex:` to `'Applying theme from dropweb-hex:`.

**Step 3: Verify no `flclashx-` remains in the file:**

```bash
grep -n "flclashx-" lib/controller.dart
```

Expected output: empty (0 matches).

**Step 4: Do NOT commit yet.** Proceed to Task 3.3.

---

### Task 3.3: Rename header keys in `lib/providers/state.dart`

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/providers/state.dart`

**Step 1: Run this grep to locate occurrences:**

```bash
grep -n "flclashx-" lib/providers/state.dart
```

Expected output:

```
469:    final value = profile?.providerHeaders['flclashx-globalmode'];
483:    final value = profile?.providerHeaders['flclashx-servicename'];
490:    final value = profile?.providerHeaders['flclashx-serverinfo'];
497:    return profile?.providerHeaders['flclashx-background'];
```

**Step 2: Replace each string literal:**

- `'flclashx-globalmode'` → `'dropweb-globalmode'`
- `'flclashx-servicename'` → `'dropweb-servicename'`
- `'flclashx-serverinfo'` → `'dropweb-serverinfo'`
- `'flclashx-background'` → `'dropweb-background'`

**Step 3: Verify:**

```bash
grep -n "flclashx-" lib/providers/state.dart
```

Expected: empty.

**Step 4: Do NOT commit yet.**

---

### Task 3.4: Rename header keys in widget files + plugins + services + main

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/main.dart`
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/plugins/vpn.dart`
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/views/dashboard/widgets/metainfo_widget.dart`
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/views/dashboard/widgets/service_info_widget.dart`
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/views/dashboard/widgets/change_server_button.dart`
- Modify: `/Users/oen/Documents/projects/dropweb-app/lib/services/subscription_notification_service.dart`

**Step 1: Run the global grep to enumerate all remaining call sites:**

```bash
grep -rn "flclashx-" lib/
```

Expected output (after Tasks 3.1, 3.2, 3.3):

```
lib/main.dart:235:    String? groupName = profile?.providerHeaders['flclashx-serverinfo'];
lib/plugins/vpn.dart:122:        profile?.providerHeaders['flclashx-serverinfo'],
lib/services/subscription_notification_service.dart:96:    // Get title from flclashx-servicename header or fallback to profile label
lib/services/subscription_notification_service.dart:98:    final svc = profile.providerHeaders['flclashx-servicename'];
lib/views/dashboard/widgets/change_server_button.dart:77:        profile.providerHeaders['flclashx-serverinfo'],
lib/views/dashboard/widgets/metainfo_widget.dart:195:    final serviceName = _decodeBase64IfNeeded(headers['flclashx-servicename']);
lib/views/dashboard/widgets/metainfo_widget.dart:196:    final logoUrl = _decodeBase64IfNeeded(headers['flclashx-servicelogo']);
lib/views/dashboard/widgets/service_info_widget.dart:159:    final serviceName = _decodeBase64IfNeeded(headers['flclashx-servicename']);
lib/views/dashboard/widgets/service_info_widget.dart:161:    final logoUrl = _decodeBase64IfNeeded(headers['flclashx-servicelogo']);
```

**Step 2: Edit each file, replacing `flclashx-` with `dropweb-` in string literals. Also replace the comment on `subscription_notification_service.dart:96` (`flclashx-servicename header` → `dropweb-servicename header`).**

**Step 3: Verify 0 remaining:**

```bash
grep -rn "flclashx-" lib/
```

Expected: empty (0 matches across all of lib/).

**Step 4: Run `flutter_analyze`**

Expected: 0 errors. If any errors → something was renamed inconsistently; re-grep and fix.

**Step 5: Commit all Wave 3 changes at once**

```bash
git add lib/models/profile.dart lib/controller.dart lib/providers/state.dart lib/main.dart lib/plugins/vpn.dart lib/views/dashboard/widgets/metainfo_widget.dart lib/views/dashboard/widgets/service_info_widget.dart lib/views/dashboard/widgets/change_server_button.dart lib/services/subscription_notification_service.dart
git commit -m "refactor: rename Remnawave header protocol flclashx-* → dropweb-*

HARD BREAKING CHANGE — no compat.

dropweb previously parsed HTTP response headers prefixed with 'flclashx-'
from subscription providers, applying the server-dictated dashboard
layout, theme, service name, logo, and behavior. That meant any
Remnawave panel configured for FlClashX would also customize dropweb —
continuing to bleed FlClashX's visual identity into our product even
after the Windows registry hijack fix.

This commit fully decouples the two protocols:
- Parser in lib/models/profile.dart accepts ONLY dropweb-* headers.
- All 20+ consumer call sites now read the renamed keys.
- Legacy flclashx-* headers are silently ignored.

COORDINATION REQUIRED before release:
- Remnawave panel template (cab.dropweb.space) must emit dropweb-*
  headers for: widgets, hex, servicename, servicelogo, serverinfo,
  view, settings, background, globalmode, custom.
- @dropwebpay_bot must emit dropweb://install-config?url=... links.

Affected headers renamed:
  flclashx-widgets     → dropweb-widgets
  flclashx-view        → dropweb-view
  flclashx-hex         → dropweb-hex
  flclashx-settings    → dropweb-settings
  flclashx-custom      → dropweb-custom
  flclashx-servicename → dropweb-servicename
  flclashx-servicelogo → dropweb-servicelogo
  flclashx-serverinfo  → dropweb-serverinfo
  flclashx-background  → dropweb-background
  flclashx-globalmode  → dropweb-globalmode

Decision: .sisyphus/plans/2026-04-20-flclashx-hard-decouple.md"
```

---

## Wave 4: Windows Uninstaller Registry Cleanup

**Owner:** Agent A
**Risk:** Low — installer-side changes, tested only on uninstall path
**Verification:** Manual: install dropweb, uninstall, open `regedit`, verify `HKCU\Software\Classes\dropweb` is gone. If FlClashX is installed, `HKCU\Software\Classes\flclash` still intact and points to FlClashX.

### Task 4.1: Delete dropweb protocol keys on uninstall

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/windows/packaging/exe/inno_setup.iss`

**Context:** The current `CurUninstallStepChanged` at lines 168-198 only removes the data directory. We also need to clean up our own protocol handlers from `HKCU\Software\Classes\<scheme>` so uninstall leaves no trace. For shared schemes (`flclash://`, `clashx://`) we must only remove them if they still point to our exe — otherwise we'd kill FlClashX's handler.

**Step 1: Open `windows/packaging/exe/inno_setup.iss`. Locate the `usPostUninstall` block at lines 187-196:**

```pascal
    usPostUninstall:
    begin
      if DirExists(ExpandConstant('{userappdata}\dropweb\dropweb')) then
      begin
        if MsgBox('Удалить пользовательские данные программы?', mbConfirmation, MB_YESNO) = IDYES then
        begin
          DelTree(ExpandConstant('{userappdata}\dropweb\dropweb'), True, True, True);
        end;
      end;
    end;
```

**Step 2: Insert the helper functions at the end of the `[Code]` block, before the `end.` pseudocode or the next `[Section]`. Find the line with `end;` that closes `procedure CurUninstallStepChanged` (around line 198) — we're adding BEFORE the `procedure CurUninstallStepChanged` declaration. Scroll up to find it (around line 168) and insert BEFORE it:**

```pascal
function GetSchemeCommand(Scheme: String): String;
var
  CmdValue: String;
  RegPath: String;
begin
  Result := '';
  RegPath := 'Software\Classes\' + Scheme + '\shell\open\command';
  if RegQueryStringValue(HKEY_CURRENT_USER, RegPath, '', CmdValue) then
    Result := CmdValue;
end;

function IsSchemeOurs(Scheme: String): Boolean;
var
  Cmd: String;
  OurExe: String;
begin
  Cmd := GetSchemeCommand(Scheme);
  OurExe := ExpandConstant('{app}\dropweb.exe');
  // Case-insensitive substring check — Inno's Pos is case-sensitive, so
  // lowercase both sides first.
  Result := (Cmd <> '') and (Pos(Lowercase(OurExe), Lowercase(Cmd)) > 0);
end;

procedure RemoveSchemeIfOurs(Scheme: String);
begin
  if IsSchemeOurs(Scheme) then
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\' + Scheme);
end;
```

**Step 3: Modify the `usPostUninstall` block (currently lines 187-196) to also remove our protocol keys. Replace the block with:**

```pascal
    usPostUninstall:
    begin
      // Remove our own protocol handlers. For the shared schemes (flclash,
      // clashx) only remove them if they still point to our exe — otherwise
      // we'd accidentally kill FlClashX's legitimate handler.
      RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\dropweb');
      RemoveSchemeIfOurs('flclash');
      RemoveSchemeIfOurs('clashx');

      if DirExists(ExpandConstant('{userappdata}\dropweb\dropweb')) then
      begin
        if MsgBox('Удалить пользовательские данные программы?', mbConfirmation, MB_YESNO) = IDYES then
        begin
          DelTree(ExpandConstant('{userappdata}\dropweb\dropweb'), True, True, True);
        end;
      end;
    end;
```

**Step 4: Verify the syntax is valid Pascal — no way to run it without rebuilding the installer. Visual check: every `begin` has a matching `end;`; every `procedure` / `function` has its closing `end;` with a semicolon; semicolons present after `RegDeleteKeyIncludingSubkeys(...)` and `RemoveSchemeIfOurs(...)`.**

**Step 5: Commit**

```bash
git add windows/packaging/exe/inno_setup.iss
git commit -m "fix(windows/installer): clean up protocol handlers on uninstall

On uninstall, delete HKCU\\Software\\Classes\\dropweb (always ours), and
conditionally delete \\flclash and \\clashx if their shell\\open\\command
still points to our exe. The conditional check prevents nuking
FlClashX's legitimate handler when the user has both apps installed and
chose to uninstall only dropweb.

Without this, previous dropweb installs that hijacked flclash:// (fixed
in Wave 1 of the hard-decouple plan) would leave dangling registry
entries pointing to a deleted dropweb.exe."
```

---

## Wave 5: Android Resource Naming Cleanup

**Owner:** Agent A
**Risk:** Low — string resource rename, touches 2 files
**Verification:** `flutter_analyze` clean. Manual: app builds on Android and the title text in the document picker (FilesProvider) still reads "dropweb" correctly.

### Task 5.1: Rename `fl_clashx` string key to `app_name`

**Files:**
- Modify: `/Users/oen/Documents/projects/dropweb-app/android/app/src/main/res/values/strings.xml`
- Modify: `/Users/oen/Documents/projects/dropweb-app/android/app/src/main/kotlin/app/dropweb/FilesProvider.kt`

**Context:** `strings.xml:3` defines `<string name="fl_clashx">dropweb</string>`. Value is correct; key name is a leftover. It's referenced from exactly one place: `FilesProvider.kt:46` uses `R.string.fl_clashx`. Rename both.

**Step 1: Open `android/app/src/main/res/values/strings.xml`. Change line 3:**

From:
```xml
    <string name="fl_clashx">dropweb</string>
```

To:
```xml
    <string name="app_name">dropweb</string>
```

**Note:** Do NOT just add a new key alongside — `app_name` might already exist in another values-*/strings.xml (e.g. values-ru/). If Android builds with a duplicate key it's a hard error. Run this grep first:

```bash
grep -rn 'name="app_name"' android/app/src/main/res/
```

If `app_name` already exists in ANY values-*.xml file → the string already has a proper name elsewhere, and we should delete the `fl_clashx` entry entirely (Step 1b below). If no other file has `app_name` → proceed with the rename above.

**Step 1b (only if `app_name` already exists elsewhere):** Delete the `<string name="fl_clashx">dropweb</string>` line entirely from `values/strings.xml`.

**Step 2: Open `android/app/src/main/kotlin/app/dropweb/FilesProvider.kt`. Locate line 46:**

```kotlin
        add(Root.COLUMN_TITLE, context!!.getString(R.string.fl_clashx))
```

**Change to:**

```kotlin
        add(Root.COLUMN_TITLE, context!!.getString(R.string.app_name))
```

**Step 3: Verify no other references to `R.string.fl_clashx` exist:**

```bash
grep -rn 'R.string.fl_clashx' android/
grep -rn '@string/fl_clashx' android/
```

Expected: both empty.

**Step 4: Run `flutter_analyze` — this won't catch Kotlin compile errors but will sanity-check Dart side is intact:**

```bash
# (via flutter_analyze MCP tool)
```

Expected: 0 errors.

**Step 5: Commit**

```bash
git add android/app/src/main/res/values/strings.xml android/app/src/main/kotlin/app/dropweb/FilesProvider.kt
git commit -m "refactor(android): rename string key fl_clashx → app_name

The value was already 'dropweb' (from Wave 1 Android rebrand), only the
key name was a leftover. Sole consumer: FilesProvider.kt line 46."
```

---

## Wave 6: End-to-End Verification

**Owner:** Agent A
**Risk:** None — read-only + manual testing
**Verification:** All 5 steps below pass.

### Task 6.1: Static analysis — final sweep

**Step 1: Run a repo-wide grep for any remaining references to the old protocols/headers/names that should be gone after Waves 1-5:**

```bash
grep -rn "flclashx-" lib/ windows/ android/ macos/ linux/
grep -rn 'fl_clashx' android/
grep -rn 'R.string.fl_clashx' android/
```

Expected: all empty.

**Step 2: Verify the remaining `flclash://` references — those that stayed on purpose:**

```bash
grep -rn 'flclash' lib/ --include="*.dart"
```

Expected: only in `lib/common/window.dart` (the `onlyIfMissing: true` registration + the migration cleanup call) and `lib/common/protocol.dart` (no references — it's scheme-agnostic). If any other file references `flclash://` as a live URL to construct, stop and investigate.

**Step 3: Run `flutter_analyze`**

Expected: 0 errors. Pre-existing warnings/infos count should match baseline (~19 warnings, ~636 infos per skill notes) within ±5.

**Step 4: Commit if anything was corrected during this sweep (usually nothing).**

---

### Task 6.2: Build Windows installer and verify manually

**Context:** Full verification requires installing the new build on a Windows VM alongside FlClashX. If no Windows VM is available right now, mark this task as deferred and flag it for the user.

**Step 1: Build Windows (requires Windows host or VM):**

```bash
# On Windows:
dart run setup.dart windows --arch amd64
```

**Step 2: Verify the installer exists at `dist/dropweb-windows-setup.exe` (exact filename depends on `make_config.yaml`).**

**Step 3: Install on a clean Windows environment that also has FlClashX installed. Verify:**

- Open `regedit.exe`, navigate to `HKEY_CURRENT_USER\Software\Classes\flclash\shell\open\command`. Confirm it points to `FlClashX.exe`, NOT `dropweb.exe`.
- Same check for `HKEY_CURRENT_USER\Software\Classes\clashx\shell\open\command` — should point to FlClashX if present.
- `HKEY_CURRENT_USER\Software\Classes\dropweb\shell\open\command` should exist and point to `dropweb.exe`.
- Click a `flclash://install-config?url=...` link in a Telegram bot — it opens FlClashX, not dropweb.
- Click a `dropweb://install-config?url=...` link — it opens dropweb.

**Step 4: Uninstall dropweb. Verify:**

- `HKEY_CURRENT_USER\Software\Classes\dropweb` is gone.
- `HKEY_CURRENT_USER\Software\Classes\flclash` is still intact (it was never ours to begin with, or was ours before the migration and we gave it back).
- FlClashX still works when `flclash://` links are clicked.

**Step 5: Test the window width constraint:**

- Launch dropweb on Windows.
- Try to drag the window wider than 600px. Confirm: can't — cursor shows resize arrow but window refuses to grow past 600px wide.
- Confirm: connect button always visible in bottom-right corner.
- Restart the app — window restores at ≤600px wide, not the old oversized state.

---

### Task 6.3: Verify Remnawave + bot coordination landed

**Context:** Wave 3 requires a coordinated update to the Remnawave panel template and `@dropwebpay_bot`. The Dart code no longer accepts `flclashx-*` headers, so if the panel still emits them, subscriptions will load but show default layout (no custom widgets, default theme).

**Step 1: Ask user to confirm panel update status:**

> "Did `cab.dropweb.space` Remnawave template get updated to emit `dropweb-*` headers? Did `@dropwebpay_bot` get updated to emit `dropweb://` links?"

**Step 2: If both YES → run the smoke test:**

- Click a subscription-add link in `@dropwebpay_bot` from a test account.
- Confirm: `dropweb` opens (not FlClashX), subscription loads, dashboard shows custom widgets + branded theme from the panel response.

**Step 3: If either NO → mark plan status as "pending backend coordination". Do not ship the Dart changes to users until both are updated. The test group will get a visual regression (default layout instead of custom) between client update and panel update.**

---

### Task 6.4: Android sanity check

**Step 1: Build Android:**

```bash
# via flutter_build MCP, or directly:
dart run setup.dart android --arch arm64
```

**Step 2: Install on test device (`flutter_install` MCP or `adb install -r`).**

**Step 3: Open the app. Navigate to document picker entry point that uses `FilesProvider` (usually via profile import file picker). Confirm the root title still reads "dropweb" — if it reads blank or the key name, the string resource rename broke something.**

**Step 4: Add a subscription from the production/test Remnawave panel. Confirm custom widgets/theme apply IF the panel emits `dropweb-*`, or fall back to default IF still on `flclashx-*`.**

---

### Task 6.5: Document what changed for the user

**Step 1: Add a single line to CHANGELOG.md under a new "Unreleased" section (do NOT rewrite history):**

```markdown
## Unreleased

### Changed (breaking for closed test group)
- Windows: dropweb no longer hijacks `flclash://` and `clashx://` deep-link handlers. Users with FlClashX installed will see their FlClashX handler restored on next launch of either app.
- Windows: window width is now capped at 600px (portrait/compact layout only). This is a design decision — the connect button, nav bar, and widget layout only exist in the ≤600px viewport.
- Subscription protocol: Remnawave panels must now emit `dropweb-*` HTTP response headers instead of `flclashx-*`. Legacy `flclashx-*` headers are silently ignored.

### Fixed
- Windows: connect button disappearing when the window was dragged wider than 600px.
- Windows: dropweb inadvertently loading FlClashX-targeted subscription links via hijacked `flclash://` protocol.
```

**Step 2: Commit:**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): record flclashx hard-decouple breaking changes"
```

---

## Rollback Plan

If any wave blows up in testing, revert is clean:

- **Wave 1 rollback:** `git revert <sha of Task 1.2 commit> <sha of Task 1.1 commit>` — restores the old unconditional `protocol.register("flclash")` / `register("clashx")` behavior. Users will see hijacking resume on next launch; the `windows_protocol_cleanup_v1` SharedPreferences flag persists but is now harmless.
- **Wave 2 rollback:** `git revert <sha of Task 2.1 commit>` — restores unconstrained window width. Users immediately regain the ability to lose their connect button.
- **Wave 3 rollback:** `git revert <sha of Task 3.4 commit>` — all 9 files revert to `flclashx-*`. Only safe if Remnawave panel is also reverted.
- **Wave 4 rollback:** `git revert <sha of Task 4.1 commit>` — installer reverts.
- **Wave 5 rollback:** `git revert <sha of Task 5.1 commit>` — Android string key reverts to `fl_clashx`.

Each wave is a single atomic commit (except Wave 3 which is 4 commits but can revert as a unit). Waves are INDEPENDENT — you can revert Wave 2 without affecting Wave 3, etc.

---

## Post-Ship Checklist

Once merged to main and a test-group build is distributed:

- [ ] Confirm test-group users see FlClashX working alongside dropweb (no hijack).
- [ ] Confirm `dropweb://install-config?...` links from `@dropwebpay_bot` open dropweb and load subscription.
- [ ] Confirm Remnawave panel responses show updated headers in devtools (Network tab on `flutter_logs` if running live).
- [ ] Confirm window width clamp doesn't surprise any test-group user (`"почему окно не растягивается?"` — expected response: "by design, it's a compact utility window").
- [ ] Delete the `windows_protocol_cleanup_v1` flag check from `lib/common/window.dart` in a future release (~1 month out) once all existing test-group users have run the migration at least once. This is tech debt but low-priority.

---

## Out of Scope (Explicitly NOT in this plan)

- Rebrand credits/about screen (chen08209, pluralplay attribution) — separate branding task, requires GPL-3.0 legal review.
- README / README_EN "Fork of FlClashX" wording — documentation polish, not runtime behavior.
- Replacing the `color_bends.frag` shader silently dying on Impeller — different bug, different priority.
- Implementing a connect button for the desktop layout — we're choosing to constrain width instead; building the desktop layout properly is a future design initiative.
- Migrating existing `flclashx-*` subscription metadata that's already stored in `providerHeaders` map (saved to shared_preferences). Those old entries will just be unused going forward — no active migration needed.
