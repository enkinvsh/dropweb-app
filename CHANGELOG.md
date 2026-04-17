## v0.4.9

- fix(android): suppress R8 warnings for unused Play Core / tika classes

- v0.4.8 CI failed at :app:minifyReleaseWithR8 with
- "Missing class com.google.android.play.core.splitcompat.SplitCompatApplication"
- and a dozen similar Play Core / tika stubs. Flutter's embedding
- references those classes for deferred components even when the feature
- is not enabled, so R8 choked when my hardened proguard-rules.pro
- (commit 2dd7106) dropped the implicit -dontwarn that the AGP-default
- rules used to carry.

- Re-add targeted `-dontwarn` for:
-   - com.google.android.play.core.** (Flutter deferred components)
-   - com.google.android.play.**      (umbrella for Play Services stubs)
-   - javax.xml.stream.**             (via transitive tika pull)
-   - org.apache.tika.**

- Runtime behaviour is unchanged — the stripped code paths are gated by
- runtime feature checks, and we don't ship the Play Core library.

## v0.4.8

- chore: bump version to 0.4.8

- fix(android): bump minSdk to 24 for flutter_secure_storage v10

- CI for v0.4.7 failed at :app:processReleaseMainManifest because the
- newly-added flutter_secure_storage 10.0.0 ships minSdkVersion=24 in
- its AndroidManifest and we were still hardcoded to 23. The merged
- manifest picks the highest min across all modules, and AGP rejected
- the mismatch instead of auto-uplifting silently.

- Bumped minSdk from 23 → 24 (Android 7.0, 2016). That's the floor
- that flutter_secure_storage v10 requires; we inherited the tighter
- requirement when Phase 9 migrated subscription URLs into the
- encrypted store. Downgrading to v9.x would drop the automatic
- Jetpack-Security→AES-GCM migration path the plugin handles for us,
- which is not worth the handful of Android 6 users.

- Also bumps pubspec to 0.4.8.

- chore: bump version to 0.4.7

- fix(android): FAB now reacts when VPN is stopped from outside the app

- The connect button used a ConsumerStatefulWidget backed by a local
- `isStart` mirror that was only updated from
- `startButtonSelectorStateProvider`. That provider's inputs
- (init/profiles/proxies) don't change when the VPN toggles, so stopping
- the tunnel via the QS tile, the foreground notification's STOP action,
- or a system revoke left the icon stuck on "stop" even though the tunnel
- was already torn down.

- Now the icon watches `runTimeProvider` directly in build(), which is
- the canonical source that TileManager.onStop resets. The breathing
- halo's ticker is driven from a post-frame callback so flipping
- AnimationController state doesn't re-enter the build phase (an earlier
- attempt to run it inline produced an ANR).

- Belt-and-braces additions:
- - AppStateManager now calls a new `syncRunStateFromNative()` on
-   AppLifecycleState.resumed. Read-only sync — it reconciles Dart-side
-   bookkeeping with the actual native runtime when the app comes back
-   without ever calling handleStart/Stop on its own.
- - TileManager.onStart/onStop log the sync event. commonPrint already
-   strips these in release via kDebugMode.

- Verified on Pixel 10: connect → notification STOP → icon flips to
- "plug" within a frame of LTE🔐 going away. No ANR, no rebuild loop.

- security: move subscription URLs to flutter_secure_storage

- Hybrid storage split: subscription URLs (plus their fallback twins) now
- live in the OS-encrypted store (Android EncryptedSharedPrefs/AES-GCM via
- Keystore, iOS Keychain, OS credential vault on desktop). Everything else
- in Config stays in SharedPreferences — cheaper, no IPC on UI reads.

- Why: subscription URLs almost always embed an auth token
- (`https://example.com/sub/<token>`). Plaintext in `shared_prefs/*.xml`
- meant anyone with root, an ADB backup, or a debug dump could harvest
- live VPN credentials.

- What changed
- - add `flutter_secure_storage: ^10.0.0` (already integrates on
-   Android/iOS/macOS/Linux/Windows; no native code here)
- - new `SecureProfileUrlStore` singleton — per-profile-id URL + fallback
- - `Preferences.saveConfig` now strips `url`/`fallbackUrl` out of the
-   Config blob before JSON-encoding to SharedPrefs, mirror-writing the
-   real values to the secure store
- - `Preferences.getConfig` rehydrates stripped profiles with values from
-   the secure store
- - One-time migration on first upgraded launch: harvest URLs already
-   sitting in SharedPrefs, copy them to the secure store, overwrite the
-   SharedPrefs blob with stripped copies, then set
-   `profile_url_migrated_v1` so we never scan plaintext again

- Verified: fresh install boots, one-time migration runs (log shows
- `Migrated 0 items` on a first-time install — expected), SOCKS port loads,
- mihomo initialises, UI renders with the real subscription label.

- perf: cache Theme.of() + debounce sticky-header scroll updates

- - widgets/scaffold.dart: _buildAppBar hit Theme.of(context) 7× per frame
-   via the InheritedWidget lookup chain. Cache theme + derived flags
-   (isDark, iconBrightness, transparentAppBar) once per build.

- - views/proxies/list.dart: ScrollController fires 60+ times/sec during a
-   scroll; we rebuilt the sticky header on every pixel. Coalesce to one
-   update per frame via addPostFrameCallback, guarded by mounted +
-   hasClients so we never touch disposed state.

- Verified on Pixel 10: dashboard renders, subscription fetch, VPN connect
- and disconnect all work; no regressions observed.

- security: harden Dart + Android surface for Play submission

- Dart:
- - http.dart: remove global cert bypass, only trust self-signed for localhost
- - system.dart: rewrite Linux sudo call — Process.start with stdin, no shell interpolation
- - request.dart: strip subscription URLs/tokens from print(), null-safe checkIp,
-   Dio timeouts (15s/15s/30s), 50 MiB size cap on profile fetches
- - controller.dart: validate profile URL (http/https only) before fetch;
-   hook PlatformDispatcher.instance.onError for isolate errors
- - state.dart: _vpnTransitionInFlight flag against double-tap start/stop race;
-   5 s timeout on service.stopVpn with graceful degradation
- - string.dart: toMd5() → SHA-256 truncated; add toSha256()
- - constant.dart: Random.secure() for unix socket path (was Mersenne Twister, 10K variants)
- - receive_profile_dialog.dart: log length only, never URLs
- - managers: async void → Future<void> (window/clash); dispose() sync + unawaited

- Android:
- - AndroidManifest: TempActivity exported=false (was open VPN toggle to any app),
-   widget receiver gets BIND_APPWIDGET, allowBackup=false,
-   data_extraction_rules.xml excludes everything, legacy flclash:// scheme removed,
-   QUERY_ALL_PACKAGES backed up by narrow <queries> block
- - file_paths.xml: scoped to configs/ + logs/ + cache/shared/ (was whole filesDir)
- - network_security_config: base cleartext=false, localhost-only exception
- - proguard-rules: full production set (services, widgets, JNI, Flutter, Kotlin, log strip)

- Misc:
- - .gitignore: local.properties, key.properties, *.keystore, signing.properties
- - pubspec: pin rationale for git-deps (re_editor, flutter_js)
- - Remove redundant Unbounded-Regular.ttf (−760 KB; Variable font covers all weights)
- - l10n: +invalidProfileUrl, +connectTv, +connectTvDesc across en/ru/ja/zh_CN

- Verified: flutter_analyze 0 errors; flutter run on Pixel 10 boots cleanly,
- subscription fetch with strict cert validation works, SOCKS protection active,
- VPN interface allocates on demand.

- fix(android): revert VpnPlugin service-engine guard — broke VPN connect

- v0.4.5 added `if (flutterEngine == null)` around VpnPlugin/AppPlugin/
- TilePlugin attachment to service engine. The intent was to avoid
- singleton VpnPlugin's MethodChannel getting rebound to service's
- binaryMessenger. In practice this broke everything:

- Service engine runs the `_service` Dart entrypoint which invokes
- MethodChannel("vpn", "start") on its own binaryMessenger. With the
- guard, those channels had no handler registered on the service engine
- side, so all MethodChannel calls from the service isolate silently
- dropped. Symptoms:
- - UI showed subscription but proxy list never loaded
- - Connect button tap did nothing (no handleStart fired)
- - Logcat went silent after save preferences

- The splash hang that guard was meant to fix was actually just an
- adb screencap quirk (native splash overlay cached in screenshot even
- after Flutter drew first frame). A real touch input removed it.

- Restore both plugin attachments. Keep Impeller=false and mesh glow.

- Update changelog

- fix(android): hardcode minSdk=23 for CI compatibility

- CI uses Flutter 3.32.8 where flutter.minSdkVersion defaults to 21.
- Core module declares minSdk=23 — Manifest merger fails with
- "minSdkVersion 21 cannot be smaller than version 23 declared in [:core]".

- Local builds on Flutter 3.41.6 worked because newer Flutter bumped
- its default to 23, masking the issue.

- chore: bump version to 0.4.5 (sync pubspec with release tag)

- fix(android): splash hang + restore bottom-right ambient glow

- Splash hang (cold-start, critical):
- - GlobalState.initServiceEngine no longer re-attaches VpnPlugin /
-   AppPlugin / TilePlugin when a MainActivity engine already owns them.
-   VpnPlugin is a Kotlin `data object` (singleton); re-attaching rebinds
-   its MethodChannel to the service engine's binaryMessenger, silently
-   breaking the UI↔native bridge and freezing the app on the launcher
-   splash screen after first resume.
- - Disabled Impeller in AndroidManifest (EnableImpeller=false). Two
-   parallel FlutterEngines (UI + VPN service) both initializing Impeller
-   Vulkan+GLES contexts caused surface creation contention on Pixel 10.
-   Custom shaders are already gone — Skia covers everything we render.

- UX:
- - MeshBackground: bottom-right tertiary glow dimmed and tightened after
-   user feedback (radius 1.8→1.3, alpha 0.42/0.18→0.28/0.10). Gives the
-   dashboard a visible but not overwhelming ambient glow in the dark
-   theme; light theme unaffected (MeshBackground short-circuits).
- - Removed the LightPillar experiment from the dashboard Stack — the
-   mesh glow is the single source of ambient light now.

- Verification: APK rebuilt, installed on Pixel 10. `AppLifecycleState
- .resumed` observed on first cold-start post-fix; splash disappears
- immediately on first touch input.

- perf(ui): fix memory leaks, cut rebuild cascades, remove dead code

- Memory leaks (3 files):
- - announce_widget, metainfo_widget, service_info_widget:
-   TapGestureRecognizer was created inline in TextSpan.recognizer and
-   never disposed — each rebuild leaked a recognizer holding callbacks
-   and context. Converted widgets to ConsumerStatefulWidget, track
-   recognizers in a List, dispose on rebuild and in dispose().

- Rebuild cascades (ProxyCard):
- - Narrowed three Consumer watches with .select() to bool predicates.
-   Sibling proxies in the same group no longer rebuild when the active
-   proxy changes — only the two cards whose selection state flipped do.
-   Applied to: _buildProxyNameText (oneline), main card Consumer,
-   _ProxyComputedMark visibility check.

- Tray CPU (Windows):
- - tray_manager._startMenuMonitor: bumped Timer.periodic from 100ms to
-   200ms (50% CPU reduction, user-imperceptible). Added debugPrint to
-   previously silent catch block. TODO noted for proper
-   SetWinEventHook event-driven implementation.

- Dead code cleanup:
- - Removed color_bends_bg.dart widget + shader asset (GLSL program has
-   been silently failing on Impeller since 2025-09-11, dashboard use
-   was commented out as a perf test). Removed shader registration from
-   pubspec.yaml and export from widgets barrel.
- - Removed commented-out ServiceMessageListener mixin, SetupParamsExt,
-   ProcessData/Fd freezed classes from models/core.dart (36 lines).
- - Removed commented CommonCardTypeExt from enum/enum.dart.
- - Removed dead corePalette conditional from providers/state.dart.

- Verification:
- - flutter analyze: 0 errors, 18 warnings, 632 infos (baseline 655).
- - Warnings/infos now concentrated in setup.dart and tool/ helpers, not
-   lib/ runtime code.

- deps(flutter_js): bump fork to 17be98e for 16KB page size alignment

- libfastdev_quickjs_runtime.so was the last native library in the APK
- with 4KB ELF LOAD alignment, triggering the Android 15+ system modal
- ('Совместимость приложений Android') on every launch on Pixel 10 and
- blocking Google Play acceptance of release builds targeting SDK 36.

- Root cause: flutter_js 0.8.3 depends on the JitPack artifact
- com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-quickjs:0.3.5,
- which was built before the 16KB page-size requirement landed. Upstream
- fast-development/android-js-runtimes shipped 0.3.6 in Sep 2025 (PR #5)
- rebuilding the QuickJS .so with -Wl,-z,max-page-size=16384.

- The enkinvsh/flutter_js fork (master) was bumped to pull 0.3.6 instead
- of 0.3.5 in commit 17be98e. This file locks dropweb-app to that commit.

- Verified: built release APK (dist/dropweb-arm64-v8a.apk), extracted
- libfastdev_quickjs_runtime.so, checked ELF p_align via python struct —
- LOAD segments now align=65536 (64KB, valid 16KB-multiple) instead of
- 4096. Installed the APK on Pixel 10, launched: no system modal appears,
- main UI renders normally. libclash.so (16KB) and libflutter.so (64KB)
- remain correctly aligned.

- feat(socks): persist random SOCKS port across app restarts

- The SOCKS protection port was regenerated on every cold start, which
- made the randomization useless for evading port-scan-based VPN detection
- (detectors care about port stability over a session, not first-launch
- entropy). Persist the port to SharedPreferences on first generation and
- reuse it on subsequent launches. Username/password are still rotated
- per-session for credential security.

- - constant.dart: add socksPortKey
- - preferences.dart: getSocksPort/saveSocksPort helpers
- - proxy_credentials.dart: generate(persistedPort:) reuses port if given
- - state.dart: load persisted port in init(), save on first generation

- Verified on Pixel 10: first launch logs 'Generated and saved new port
- 33932', subsequent launches log 'Loaded persisted port: 33932'.

- build(android): 16KB page alignment — defensive hardening

- Android 16 on Pixel 10 fires a system warning dialog claiming libclash,
- libflutter, libdatastore, camera libs are not 16KB-aligned. Reality
- check via llvm-readelf -l on the installed debug APK:

-   libclash.so                       0x4000  (16KB OK — Go already 16KB-safe)
-   libflutter.so                     0x10000 (64KB OK — Flutter 3.38+ fixed)
-   libdatastore_shared_counter.so    0x4000  (16KB OK)
-   libimage_processing_util_jni.so   0x4000  (16KB OK)
-   libsurface_util_jni.so            0x4000  (16KB OK)
-   libfastdev_quickjs_runtime.so     0x1000  (4KB — the actual offender)

- zipalign -P 16 passes, so Play Store won't reject. The Android 16
- warning was generic and over-listed. Real outstanding work is
- rebuilding enkinvsh/flutter_js fork with max-page-size=16384.

- This commit applies precautionary 16KB flags so future builds stay
- compliant even if Go/NDK/deps regress:

- - setup.dart: CGO_LDFLAGS='-O2 -s -w -Wl,-z,max-page-size=16384' for
-   Android Go lib builds (libclash.so). No-op on other platforms.

- - build.gradle.kts: useLegacyPackaging=false. Legacy packaging extracts
-   .so at install time which destroys 16KB alignment at runtime. Required
-   by Google Play for Android 15+ targets.

- - build.gradle.kts: force androidx.datastore 1.1.7. Version 1.2.0 ships
-   a 4KB-aligned libdatastore_shared_counter.so and breaks 16KB compliance.
-   Pin until 1.3.0 (with proper alignment) stabilizes.
-   Refs: flutter/flutter#182898

- Also includes pre-existing minSdk flutter.minSdkVersion revert
- (core module still needs ≥23 at runtime — comment preserved).

- fix(ui): audit-found UX regressions on Pixel 10

- Found during 2026-04-17 full UI audit on Pixel 10 Android 16:

- 1. AccessView app bar title 'Контроль доступа приложений' was being
-    truncated to 'Контроль доступа прил...'. OpenDelegate passed the
-    long appAccessControl label; the switch row INSIDE AccessView
-    already shows the long form, so the app bar only needs the short
-    'Контроль доступа' — eliminates both truncation and redundancy.

- 2. MagicRingsOverlay is placed at scaffold level and rendered on every
-    dark-themed page with a bottomNavigationBar. After connect, the
-    rings stayed visible on Settings and sub-pages, overlapping
-    content. Gate visibility on isCurrentPageProvider(PageLabel.dashboard)
-    so rings only animate on the dashboard where the connect button
-    lives.

- 3. StartButton breathing glow alpha was 0.15-0.3 (from Tier-1 perf
-    pass). Invisible on OLED Pixel 10. Bumped to 0.25-0.45 — still
-    gentler than the pre-Tier-1 0.2-0.5, now actually visible.

- fix(windows): complete Wave 1 rebrand — kill FlClashX shared config

- Runner.rc exe metadata still identified as 'clashx' by 'com.follow'.
- inno_setup.iss killed non-existent FlClashCore.exe/FlClashHelperService.exe
- and its uninstaller wiped {userappdata}\com.follow\clashx — the SAME
- folder original FlClashX uses. Installing both apps side-by-side would
- let dropweb's uninstaller nuke FlClashX's config.

- - Runner.rc: CompanyName/InternalName/ProductName → dropweb, copyright 2026
- - inno_setup.iss: kill DropwebCore.exe/DropwebHelperService.exe (real names)
- - inno_setup.iss: uninstaller path → {userappdata}\dropweb\dropweb
-   (matches path_provider Windows layout from new Runner.rc values)

- Note: existing Windows users upgrading to this version will see their
- settings reset (old path was com.follow\clashx, new is dropweb\dropweb).
- No migration path — clean break.

- docs: add SEO keywords (Clash Meta, DPI bypass, split tunneling, Xray-core)

- docs: fix legal phrasing, remove dropweb.org links, improve disclaimer

- docs: rewrite README with Gemini 3.1 — engineer-to-engineer tone, detection protection focus

- - Honest fork positioning (FlClashX → dropweb for non-tech users)
- - Added detection protection section with Habr link (YourVPNDead/RKNHardering)
- - Build from source instructions (setup.dart)
- - Removed AI service name-dropping (was SEO bullshit)
- - for-the-badge style badges
- - Dual language (RU/EN)

- Update changelog

## v0.4.5

- fix(android): hardcode minSdk=23 for CI compatibility

- CI uses Flutter 3.32.8 where flutter.minSdkVersion defaults to 21.
- Core module declares minSdk=23 — Manifest merger fails with
- "minSdkVersion 21 cannot be smaller than version 23 declared in [:core]".

- Local builds on Flutter 3.41.6 worked because newer Flutter bumped
- its default to 23, masking the issue.

- chore: bump version to 0.4.5 (sync pubspec with release tag)

- fix(android): splash hang + restore bottom-right ambient glow

- Splash hang (cold-start, critical):
- - GlobalState.initServiceEngine no longer re-attaches VpnPlugin /
-   AppPlugin / TilePlugin when a MainActivity engine already owns them.
-   VpnPlugin is a Kotlin `data object` (singleton); re-attaching rebinds
-   its MethodChannel to the service engine's binaryMessenger, silently
-   breaking the UI↔native bridge and freezing the app on the launcher
-   splash screen after first resume.
- - Disabled Impeller in AndroidManifest (EnableImpeller=false). Two
-   parallel FlutterEngines (UI + VPN service) both initializing Impeller
-   Vulkan+GLES contexts caused surface creation contention on Pixel 10.
-   Custom shaders are already gone — Skia covers everything we render.

- UX:
- - MeshBackground: bottom-right tertiary glow dimmed and tightened after
-   user feedback (radius 1.8→1.3, alpha 0.42/0.18→0.28/0.10). Gives the
-   dashboard a visible but not overwhelming ambient glow in the dark
-   theme; light theme unaffected (MeshBackground short-circuits).
- - Removed the LightPillar experiment from the dashboard Stack — the
-   mesh glow is the single source of ambient light now.

- Verification: APK rebuilt, installed on Pixel 10. `AppLifecycleState
- .resumed` observed on first cold-start post-fix; splash disappears
- immediately on first touch input.

- perf(ui): fix memory leaks, cut rebuild cascades, remove dead code

- Memory leaks (3 files):
- - announce_widget, metainfo_widget, service_info_widget:
-   TapGestureRecognizer was created inline in TextSpan.recognizer and
-   never disposed — each rebuild leaked a recognizer holding callbacks
-   and context. Converted widgets to ConsumerStatefulWidget, track
-   recognizers in a List, dispose on rebuild and in dispose().

- Rebuild cascades (ProxyCard):
- - Narrowed three Consumer watches with .select() to bool predicates.
-   Sibling proxies in the same group no longer rebuild when the active
-   proxy changes — only the two cards whose selection state flipped do.
-   Applied to: _buildProxyNameText (oneline), main card Consumer,
-   _ProxyComputedMark visibility check.

- Tray CPU (Windows):
- - tray_manager._startMenuMonitor: bumped Timer.periodic from 100ms to
-   200ms (50% CPU reduction, user-imperceptible). Added debugPrint to
-   previously silent catch block. TODO noted for proper
-   SetWinEventHook event-driven implementation.

- Dead code cleanup:
- - Removed color_bends_bg.dart widget + shader asset (GLSL program has
-   been silently failing on Impeller since 2025-09-11, dashboard use
-   was commented out as a perf test). Removed shader registration from
-   pubspec.yaml and export from widgets barrel.
- - Removed commented-out ServiceMessageListener mixin, SetupParamsExt,
-   ProcessData/Fd freezed classes from models/core.dart (36 lines).
- - Removed commented CommonCardTypeExt from enum/enum.dart.
- - Removed dead corePalette conditional from providers/state.dart.

- Verification:
- - flutter analyze: 0 errors, 18 warnings, 632 infos (baseline 655).
- - Warnings/infos now concentrated in setup.dart and tool/ helpers, not
-   lib/ runtime code.

- deps(flutter_js): bump fork to 17be98e for 16KB page size alignment

- libfastdev_quickjs_runtime.so was the last native library in the APK
- with 4KB ELF LOAD alignment, triggering the Android 15+ system modal
- ('Совместимость приложений Android') on every launch on Pixel 10 and
- blocking Google Play acceptance of release builds targeting SDK 36.

- Root cause: flutter_js 0.8.3 depends on the JitPack artifact
- com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-quickjs:0.3.5,
- which was built before the 16KB page-size requirement landed. Upstream
- fast-development/android-js-runtimes shipped 0.3.6 in Sep 2025 (PR #5)
- rebuilding the QuickJS .so with -Wl,-z,max-page-size=16384.

- The enkinvsh/flutter_js fork (master) was bumped to pull 0.3.6 instead
- of 0.3.5 in commit 17be98e. This file locks dropweb-app to that commit.

- Verified: built release APK (dist/dropweb-arm64-v8a.apk), extracted
- libfastdev_quickjs_runtime.so, checked ELF p_align via python struct —
- LOAD segments now align=65536 (64KB, valid 16KB-multiple) instead of
- 4096. Installed the APK on Pixel 10, launched: no system modal appears,
- main UI renders normally. libclash.so (16KB) and libflutter.so (64KB)
- remain correctly aligned.

- feat(socks): persist random SOCKS port across app restarts

- The SOCKS protection port was regenerated on every cold start, which
- made the randomization useless for evading port-scan-based VPN detection
- (detectors care about port stability over a session, not first-launch
- entropy). Persist the port to SharedPreferences on first generation and
- reuse it on subsequent launches. Username/password are still rotated
- per-session for credential security.

- - constant.dart: add socksPortKey
- - preferences.dart: getSocksPort/saveSocksPort helpers
- - proxy_credentials.dart: generate(persistedPort:) reuses port if given
- - state.dart: load persisted port in init(), save on first generation

- Verified on Pixel 10: first launch logs 'Generated and saved new port
- 33932', subsequent launches log 'Loaded persisted port: 33932'.

- build(android): 16KB page alignment — defensive hardening

- Android 16 on Pixel 10 fires a system warning dialog claiming libclash,
- libflutter, libdatastore, camera libs are not 16KB-aligned. Reality
- check via llvm-readelf -l on the installed debug APK:

-   libclash.so                       0x4000  (16KB OK — Go already 16KB-safe)
-   libflutter.so                     0x10000 (64KB OK — Flutter 3.38+ fixed)
-   libdatastore_shared_counter.so    0x4000  (16KB OK)
-   libimage_processing_util_jni.so   0x4000  (16KB OK)
-   libsurface_util_jni.so            0x4000  (16KB OK)
-   libfastdev_quickjs_runtime.so     0x1000  (4KB — the actual offender)

- zipalign -P 16 passes, so Play Store won't reject. The Android 16
- warning was generic and over-listed. Real outstanding work is
- rebuilding enkinvsh/flutter_js fork with max-page-size=16384.

- This commit applies precautionary 16KB flags so future builds stay
- compliant even if Go/NDK/deps regress:

- - setup.dart: CGO_LDFLAGS='-O2 -s -w -Wl,-z,max-page-size=16384' for
-   Android Go lib builds (libclash.so). No-op on other platforms.

- - build.gradle.kts: useLegacyPackaging=false. Legacy packaging extracts
-   .so at install time which destroys 16KB alignment at runtime. Required
-   by Google Play for Android 15+ targets.

- - build.gradle.kts: force androidx.datastore 1.1.7. Version 1.2.0 ships
-   a 4KB-aligned libdatastore_shared_counter.so and breaks 16KB compliance.
-   Pin until 1.3.0 (with proper alignment) stabilizes.
-   Refs: flutter/flutter#182898

- Also includes pre-existing minSdk flutter.minSdkVersion revert
- (core module still needs ≥23 at runtime — comment preserved).

- fix(ui): audit-found UX regressions on Pixel 10

- Found during 2026-04-17 full UI audit on Pixel 10 Android 16:

- 1. AccessView app bar title 'Контроль доступа приложений' was being
-    truncated to 'Контроль доступа прил...'. OpenDelegate passed the
-    long appAccessControl label; the switch row INSIDE AccessView
-    already shows the long form, so the app bar only needs the short
-    'Контроль доступа' — eliminates both truncation and redundancy.

- 2. MagicRingsOverlay is placed at scaffold level and rendered on every
-    dark-themed page with a bottomNavigationBar. After connect, the
-    rings stayed visible on Settings and sub-pages, overlapping
-    content. Gate visibility on isCurrentPageProvider(PageLabel.dashboard)
-    so rings only animate on the dashboard where the connect button
-    lives.

- 3. StartButton breathing glow alpha was 0.15-0.3 (from Tier-1 perf
-    pass). Invisible on OLED Pixel 10. Bumped to 0.25-0.45 — still
-    gentler than the pre-Tier-1 0.2-0.5, now actually visible.

- fix(windows): complete Wave 1 rebrand — kill FlClashX shared config

- Runner.rc exe metadata still identified as 'clashx' by 'com.follow'.
- inno_setup.iss killed non-existent FlClashCore.exe/FlClashHelperService.exe
- and its uninstaller wiped {userappdata}\com.follow\clashx — the SAME
- folder original FlClashX uses. Installing both apps side-by-side would
- let dropweb's uninstaller nuke FlClashX's config.

- - Runner.rc: CompanyName/InternalName/ProductName → dropweb, copyright 2026
- - inno_setup.iss: kill DropwebCore.exe/DropwebHelperService.exe (real names)
- - inno_setup.iss: uninstaller path → {userappdata}\dropweb\dropweb
-   (matches path_provider Windows layout from new Runner.rc values)

- Note: existing Windows users upgrading to this version will see their
- settings reset (old path was com.follow\clashx, new is dropweb\dropweb).
- No migration path — clean break.

- docs: add SEO keywords (Clash Meta, DPI bypass, split tunneling, Xray-core)

- docs: fix legal phrasing, remove dropweb.org links, improve disclaimer

- docs: rewrite README with Gemini 3.1 — engineer-to-engineer tone, detection protection focus

- - Honest fork positioning (FlClashX → dropweb for non-tech users)
- - Added detection protection section with Habr link (YourVPNDead/RKNHardering)
- - Build from source instructions (setup.dart)
- - Removed AI service name-dropping (was SEO bullshit)
- - for-the-badge style badges
- - Dual language (RU/EN)

- Update changelog

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
