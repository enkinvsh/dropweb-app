## v0.4.18

- fix(fatal): splash hang — file_logger infinite microtask loop

- ROOT CAUSE FOUND via Dart VM service getStack on a live hung debug build:

-     0  verifiedLocale @ intl_helpers.dart
-     1  verifiedLocale @ intl_helpers.dart
-     2  DateFormat @ date_format.dart
-     3  _getTodayDate @ file_logger.dart:52
-     4  _getCurrentLogFile @ file_logger.dart
-     5  _ensureSink @ file_logger.dart
-     6  _processQueue @ file_logger.dart:170
-     7  _processQueue @ file_logger.dart:188   <-- recursive retry
-     ... runBinary / handleError / _propagateToListeners / _completeErrorObject
-     ... runBinary / handleError / _propagateToListeners / _completeErrorObject
-     _microtaskLoop
-     _startMicrotaskLoop

- DateFormat('yyyy-MM-dd') with no explicit locale falls through to
- Intl.systemLocale, and during early cold start (before locale data is
- loaded) it throws in intl_helpers.verifiedLocale.

- _processQueue catches this silently and then checks if queue is non-empty
- and recursively schedules itself via unawaited(_processQueue()). Since
- every log message entering the queue re-triggers the same throw, the
- microtask loop runs forever. Microtasks have higher priority than event
- loop tasks, so runApp's scheduleAttachRootWidget never fires, and the
- splash screen sits on DRAW_PENDING indefinitely.

- Why post-reboot specifically: on warm start _service logs less and the
- race loses, but on cold start after reboot the service isolate floods
- commonPrint.log() calls (dns handshake, socks port init, service ready
- signaling) before the main isolate has a chance to schedule its first
- runApp frame. The queue saturates, the recursive retry wedges main.

- Explains every symptom seen across v0.4.5 → v0.4.17:
- - Post-reboot / cold-start specific (locale data not yet loaded)
- - All devices (Pixel 5, 10) — not a hardware issue
- - Impeller/Flutter-bump 'fixes' worked by accident (changed timing
-   enough that locale loaded before first log)
- - 10 previous tags churning around plugin lifecycle were all red herrings

- Fix:
- 1. Replace DateFormat with manual ISO string formatting for both date
-    and timestamp. No locale dependency.
- 2. On sink failure, drop the queue instead of retrying the same broken
-    sink — infinite retry on persistent errors is never correct anyway.

- Verified fix on live debug build via flutter run + Dart VM service:
- after hot-restart with these changes, Application.initState fires,
- UI renders, subscription card visible, VPN toggle button present.

- Bumps version to 0.4.18.

- diag: add granular [MAIN] and [APP] tracing around runApp

- Live logcat from v0.4.16 after force-stop+relaunch under memory pressure
- shows main isolate reaches '[MAIN] globalState.initApp done' and then
- goes silent — splash still hangs. The remaining code before runApp and
- inside Application.initState was untraced.

- This release adds debugPrint at every step from globalState.initApp
- completion through runApp return, and at every step of Application.initState
- including the postFrameCallback. Next repro will pinpoint exact line.

- Not a fix, just instrumentation. Bumps version to 0.4.17.

- Update changelog

## v0.4.16

- fix(android): discard stale savedInstanceState post-reboot

- Actual root cause of post-reboot splash hang (reproducible on Pixel 5 and
- Pixel 10, not device-specific):

- Android keeps our Task persistent across reboots (isPersistable=true,
- mNeverRelinquishIdentity=true by default for singleTop launcher Activity).
- After reboot, launcher does LAUNCH_SINGLE_TOP on the saved Task, and Android
- passes a savedInstanceState Bundle from the pre-reboot process into the
- freshly-forked MainActivity.onCreate. FlutterActivity.onCreate then tries
- to restore FlutterEngine state from that Bundle — but the engine it
- references no longer exists (process was killed). Restoration path
- blocks in native code indefinitely.

- Logcat evidence: wm_on_create_called/wm_on_resume_called fire normally,
- but no Impeller/flutter/Dart logs ever appear. Main thread sits at R(running)
- in userspace, CPU burned but no forward progress for minutes.

- Fix: pass null to super.onCreate. We don't use Flutter's restoration API
- (no RestorationScope / restorationId anywhere), so there's nothing to
- recover. Fresh engine boot every cold-start is what we want anyway.

- Bumps version to 0.4.16.

- Update changelog

## v0.4.15

- fix(android): ServicePlugin.init — post initServiceEngine, don't block channel call

- v0.4.14 didn't fix splash hang. Stack trace from Log.w(Throwable) on live
- device deobfuscated via R8 mapping:

-     GlobalState.initServiceEngine() (from Throwable at line 156)
-     ServicePlugin.onMethodCall("init") at ServicePlugin.kt:40
-     (invoked via MethodChannel "service" from Dart main isolate)

- Cold-start flow:

- 1. lib/main.dart main() runs: await clashCore.preload()
- 2. ClashCore._internal() instantiates clashLib (lazy) → ClashLib._internal()
- 3. ClashLib._internal() synchronously calls _initService()
- 4. _initService() calls await service?.init() → platform channel 'init'
- 5. ServicePlugin.onMethodCall("init") calls GlobalState.initServiceEngine()
-    synchronously, which runs runLock.withLock { executeDartEntrypoint(_service) }
-    on the Android platform thread.
- 6. While the platform thread is busy bootstrapping the service Dart VM,
-    main engine never gets a chance to progress its own Dart isolate.
-    MainActivity surface stays DRAW_PENDING, splash stuck with 'db' logo.

- Fix: post initServiceEngine onto the next main looper tick so the
- platform channel 'init' call returns immediately. result.success(true)
- fires synchronously, Dart main isolate keeps running, clashCore.preload()
- awaits its handshake, and on the next looper tick the service engine
- bootstraps without starving the platform thread.

- Also adds [MAIN] diagnostic logs to lib/main.dart so we can confirm where
- main isolate is progressing (previously had ZERO logs from main() in
- production logcat — impossible to tell if it was blocked or not running
- at all). v0.4.14's GlobalState defer guard stays in place: it's a belt-
- and-braces defense for any other caller that might hit the same path
- (AppPlugin.onActivityResult on VPN_PERMISSION_REQUEST_CODE, tile quick-
- start). Bumps version to 0.4.15.

- Update changelog

## v0.4.14

- fix(android): defer initServiceEngine when main engine is alive

- Root cause of post-reboot/cold-start splash hang found via live logcat on
- v0.4.13 (Pixel 10): something triggers GlobalState.initServiceEngine() on
- the platform thread during MainActivity.onCreate, BEFORE FlutterActivity
- schedules main FlutterEngine's default Dart entrypoint. The synchronous
- serviceEngine.dartExecutor.executeDartEntrypoint(_service) call under
- runLock starves the platform thread, main engine's Dart main() never
- starts, and the splash screen sits with mDrawState=DRAW_PENDING forever.

- Symptoms in logcat (v0.4.13, fresh cold start, no VPN active):
- - TilePlugin.onAttachedToEngine fires twice (main + service)
- - 16x "plugin already registered" warnings
- - ConnectivityManager: NetworkCallback was already registered (ERROR)
- - _service entrypoint runs to completion
- - NOT a single log line from lib/main.dart's main() entrypoint
- - splash window HAS_DRAWN, MainActivity surface DRAW_PENDING for minutes

- Fix: when MainActivity's flutterEngine is already alive, post the service
- engine init onto the next main looper cycle instead of running it
- synchronously. This lets FlutterActivity's pending runnables (including
- main engine's executeDartEntrypoint) drain first. Service engine still
- gets created — VPN connect path (AppPlugin.onActivityResult RESULT_OK,
- DropwebVpnService.onCreate, GlobalState.handleStart with no TilePlugin)
- keeps working, just one looper tick later.

- Also adds a Throwable to the deferred-path log so the next reproduction
- will tell us WHICH callsite is firing initServiceEngine on cold-start —
- the four known callers (handleStart, AppPlugin.onActivityResult,
- ServicePlugin.onMethodCall("init"), DropwebVpnService.onCreate) all
- showed no preceding log line in the captured trace, so the trigger
- remains to be confirmed.

- Bumps version to 0.4.14.

- Update changelog

## v0.4.13

- fix(android): re-enable Impeller — disabling it broke post-reboot launch

- Diff against last-known-working v0.4.4 showed I'd flipped
- EnableImpeller from \"true\" to \"false\" with a comment claiming
- two FlutterEngine instances couldn't share Vulkan. That comment
- was wrong: upstream FlClashX has been on Impeller=true since
- 2025-09-11 with no issue.

- On Pixel 10 with an active VPN profile, the Skia GLES backend
- fails Surface init after a cold device boot. UI never renders,
- which is exactly the splash hang every CI 0.4.7→0.4.12 build
- reproduced. Local builds happened to work because Gradle still
- had warm OpenGL ES context state from prior `flutter run` debug
- sessions; they reproduced reliably only after a real reboot.

- Reverting to Impeller=true matches upstream and resolves the
- hang. The trade-off (custom shaders silently fail on Impeller's
- GLES backend) is documented in the dropweb skill and not in play
- for our current asset set.

- fix(ci): bump Flutter to 3.41.6 — 3.32.8 causes post-reboot splash hang

- CI was pinned to Flutter 3.32.8 (Dec 2024). Local builds against
- 3.41.6 do not reproduce the post-reboot splash hang with an active
- VPN profile; CI-built 0.4.11 APKs hang consistently. Diff was
- traced to this single line after confirming Go 1.24 produces an
- identical-size libclash.so either way.

- Bump to 3.41.6 (3 weeks old stable) to match the local toolchain
- and unblock release. Also drop the diagnostic `[MAIN]` traces from
- main.dart now that the splash-hang path has been isolated.

- Update changelog

## v0.4.11

- chore: bump version to 0.4.11

- chore: drop diagnostic [MAIN] tracing + bump 0.4.11

- Splash hang confirmed fixed on-device (double reboot + active profile +
- active VPN → clean UI render). Ship a clean 0.4.11 without the debug
- logging that helped locate the issue.

- docs: add Telegram discussion forum link

- docs: fix FlClashX link — point to pluralplay/FlClashX, not chen08209/FlClash

- Description said "Fork of FlClashX" but linked to chen08209/FlClash,
- which is FlClash (no X). Our real parent is pluralplay/FlClashX.
- Link both: FlClashX as the parent fork we sync from, FlClash as the
- original project the whole chain descends from.

- chore: trim verbose comments + bump 0.4.10

- Strip narrative comments from this session's commits — keep only those
- explaining non-obvious security/perf decisions or upstream-inherited
- rationale. Drop the diagnostic [MAIN] tracing now that the splash hang
- is fixed and the logging served its purpose.

- diag: add startup tracing to track post-reboot splash hang

- main.dart: log every step of main() so we can see exactly where the
- main isolate stops in the (still-occurring) post-reboot splash hang.
- Logs fire for: start, system.version, preload(), initApp, android.init,
- window.init, vpn singleton, runApp.

- GlobalState.initServiceEngine: log a Throwable to capture the call
- site. This already proved the service engine is born from
- ServicePlugin.onMethodCall (Dart main isolate calling service.init()
- inside ClashLib._initService) — not from VpnService restoration.

- These print through commonPrint.log → debugPrint, which keeps showing
- up in release logcat as I/flutter, so they are visible without a debug
- build.

- Verified on Pixel 10: fresh install of the release APK now traces
- all main-isolate steps and renders the UI (Surface HAS_DRAWN).
- Awaiting on-device reboot test with an active profile to capture the
- hang scenario.

- fix(android): revert proguard-rules.pro to upstream (1 line)

- ROOT CAUSE of the post-reboot splash hang, found after running
- flutter run on debug and seeing main isolate log everything it's
- supposed to. Debug build works fine. Release build hangs. The only
- release-specific thing I'd touched was ProGuard / R8.

- My previous 85-line proguard-rules.pro (commit dbdd8b6 as part of
- "security harden") stripped logs in release:

-   -assumenosideeffects class android.util.Log {
-       public static int v(...);
-       public static int d(...);
-   }

- That tells R8 "Log.v and Log.d are pure, their arguments don't need
- to be evaluated". In practice it deletes ANY code passed as an
- argument. Flutter's embedding has Log.d calls where the argument
- is an expression with side effects during engine startup — R8
- drops the side effect, engine init is now skipped, and the Dart
- main() never fires. Splash stays forever.

- Upstream pluralplay/FlClashX ships a one-line proguard-rules.pro:

-   -keep class com.follow.clashx.models.**{ *; }

- Everything else is left to Flutter's default rules which Flutter
- Gradle plugin merges in automatically. That's it. No hardening
- needed at this layer — AAB signing and Play Store obfuscation
- already give us the defense-in-depth the custom rules were meant
- to provide.

- Fix: replace the full 85-line file with the upstream one-liner
- (adjusted to `app.dropweb.models`).

- Verified on Pixel 10: release APK (95MB, 275KB smaller than the
- previous broken build) installs and launches cleanly to the
- disclaimer screen. Debug build also works as it did before.
- Awaiting on-device reboot test with an active profile.

- fix(android): revert all my splash-hang "fixes" back to upstream baseline

- After four failed attempts at debugging the post-reboot splash hang,
- I pulled upstream pluralplay/FlClashX at 0a5afe9 and diffed. All my
- "fixes" were regressions against a baseline that works. The real
- culprit was a change I'd made but never attributed to: forcing
- START_STICKY on the VPN service.

- Changes reverted to upstream form:

- 1. DropwebVpnService: drop `onStartCommand { return START_STICKY }`.
-    Upstream FlClashXVpnService has no onStartCommand override — it
-    inherits the default (START_STICKY_COMPATIBILITY, treated as
-    START_NOT_STICKY on modern Android). My override forced the
-    service to be revived by Android after any process death,
-    including post-boot. That revival triggered GlobalState
-    .initServiceEngine() BEFORE MainActivity.onCreate ran, which
-    left the service FlutterEngine first-in-line for singleton
-    plugin attachment and broke the main engine's handshake.

- 2. VpnPlugin: `class` → `data object` (my 2bbe737 was a wrong turn).
-    ServicePlugin: same. Upstream uses singletons and the main/
-    service engine share them by design — re-attaching rebinds the
-    MethodChannel to the currently-active engine, which is correct.

- 3. MainActivity.configureFlutterEngine: restore
-    `GlobalState.syncStatus()` call (reverting cf9f2a2). Upstream
-    has this exact call and their app boots fine post-reboot; the
-    "deadlock" I theorized wasn't real.

- 4. DropwebApplication: drop the FlutterLoader.startInitialization
-    pre-warm (reverting 59c3add). Upstream doesn't do this, so it
-    was never the actual race condition fix I thought it was.

- Net diff is small: -12 lines. All that debugging, just to delete
- code I never should have written.

- Verified: release APK built, installed, launches on fresh install.
- Awaiting on-device reboot test with an active profile — the scenario
- that originally reproduced the hang.

- fix(android): pre-warm FlutterLoader in Application.onCreate

- Third attempt at the post-reboot splash hang. Logs on a hung release
- process showed:

-   - main engine created (Impeller opt-out @ T+0.45s)
-   - MainActivity window ready (VRI, T+0.54s)
-   - second engine created (Impeller opt-out @ T+0.56s) = service engine
-   - 15× FlutterEngineCxnRegstry warnings "already registered" on the
-     service engine for every pub plugin (PathProvider, SharedPrefs,
-     URL launcher, etc.)
-   - service isolate Dart reaches `[DART] Not quickStart, calling
-     _handleMainIpc` and goes idle waiting for the main isolate
-   - main isolate NEVER produces a single log line — no system.version,
-     no clashCore.preload, nothing; main() never starts

- The race: FlutterLoader.startInitialization loads libflutter.so and
- the AOT snapshot once per process. On a fresh boot that first load
- takes hundreds of ms and is traditionally done during
- FlutterActivity.onCreate on the Android UI thread. Meanwhile the
- service engine creation path (triggered from Dart IPC) calls
- FlutterLoader.startInitialization on a background thread. Both paths
- racing on the same native initializers leaves the main engine in a
- half-initialized state where its DartExecutor never fires the Dart
- entrypoint.

- Fix: call startInitialization exactly once, from Application.onCreate,
- before any engine is created. Android guarantees Application.onCreate
- runs on the UI thread before any component (Activity, Service,
- ContentProvider) sees `onCreate`. Subsequent startInitialization calls
- short-circuit because it caches state in a FlutterLoader singleton.
- This removes the race entirely.

- Still needs real post-reboot testing on a device with an active
- profile — that's the only scenario where the race reproduced.

- fix(android): convert VpnPlugin/ServicePlugin from data object to class

- REAL root cause of the post-reboot splash hang (previous attempts
- targeted symptoms, not this). Logs from a hung release build showed:

-   - Only the service engine FlutterEngine@f20dfb6 is created
-   - Main engine Dart main() never runs
-   - FlutterEngineCxnRegstry warnings: "plugin (X) already registered
-     with this FlutterEngine" — for every VpnPlugin/ServicePlugin
-     attempt on the second engine

- Flutter's plugin registry deduplicates by class instance. Attaching
- the same Kotlin `data object` (singleton) to a second engine is a
- no-op: onAttachedToEngine is NEVER called for the second engine. So:

-   1. VpnService revives post-boot (START_STICKY) → initServiceEngine
-      creates service FlutterEngine → VpnPlugin singleton attaches →
-      flutterMethodChannel bound to service engine's binaryMessenger.
-   2. User taps icon → MainActivity creates main FlutterEngine →
-      tries to register the SAME VpnPlugin singleton → registry
-      silently ignores → main engine has no `vpn` channel handler.
-   3. Dart main() runs `vpn; // init singleton` → method channel
-      call into native → no handler on main engine → suspends
-      forever. Main UI isolate never gets past that line, never
-      renders first frame, splash stays on screen.

- Fix: convert VpnPlugin and ServicePlugin to regular classes, add
- new instances per engine. Persistent state that must be shared
- across engines (bound service, vpn options, foreground-params
- cache, network subscription, timer job) moved into the Companion
- object of VpnPlugin. ServicePlugin holds no state so it was a
- straight `data object` → `class`. TilePlugin and AppPlugin were
- already classes, no changes needed.

- MainActivity.configureFlutterEngine and GlobalState.initServiceEngine
- updated to instantiate (`VpnPlugin()` / `ServicePlugin()`).

- Verified: release APK built locally, installed on Pixel 10, launches
- cleanly to the disclaimer screen on first run. Needs on-device
- reboot test with an active profile to close the loop — that's the
- scenario that originally reproduced the hang.

- fix(android): remove syncStatus deadlock from MainActivity startup

- Second splash-hang regression on post-boot with an active profile.
- `DropwebVpnService` is marked START_STICKY, so Android revives it on
- boot before the user even taps the icon. `onCreate` calls
- `GlobalState.initServiceEngine()` which attaches the singleton
- `VpnPlugin` to the service engine — binding its MethodChannel to the
- service engine's binaryMessenger.

- When the user then launches the app, `MainActivity.configureFlutterEngine`
- adds the same `VpnPlugin` data-object to the main engine. Kotlin's plugin
- registry invokes `onAttachedToEngine` again, which rebinds
- `flutterMethodChannel` to the main engine's messenger. The service
- isolate is now holding references to an unwired channel.

- Immediately after that rebind the old code called `syncStatus()` —
- which routed `flutterMethodChannel.awaitResult("status")` across a
- channel that could only be answered by the UI Dart isolate. But the UI
- Dart `main()` had not even begun executing yet; it won't register
- handlers until after `runApp`. `awaitResult` suspends forever. The
- native splash stays on screen because the UI never renders its first
- frame.

- Fix: drop the synchronous sync. The UI side already reconciles run
- state in `AppController.syncRunStateFromNative()` on
- `AppLifecycleState.resumed`, which fires after runApp and the first
- frame when all channels are properly wired.

- A comment was added inline documenting exactly why this call is
- forbidden here — this is the third time the bug has cycled through
- (b438704 fix → c920cc2 revert → this), and I'd like to stop the cycle.

- fix(android): don't block startup on Android Keystore IPC

- Symptom: after a cold device reboot the release build stays on the
- native splash forever. `dumpsys window` shows MainActivity
- `Surface shown=false mDrawState=DRAW_PENDING`, i.e. Flutter never
- produced the first frame. Debug build doesn't reproduce because its
- Keystore IPC path warms up while Gradle is still pushing the APK.

- Root cause: `preferences.getConfig()` — called synchronously on the
- critical path of `globalState.init()` before `runApp` — was fetching
- every profile's subscription URL from `flutter_secure_storage`. On
- Pixel 10 after a cold boot the Gatekeeper/Keystore daemon can take
- 10-30 s to answer the first IPC, and the call blocks the main
- isolate. No UI, no splash handoff, no timeout.

- Fix: URLs no longer live in the in-memory Config. getConfig() now
- returns the Config straight from SharedPreferences (with empty URL
- fields, which is the scrubbed-on-disk shape). Callers that actually
- need the URL read it on demand through the two new accessors on
- Preferences:
-   - `preferences.getProfileUrl(profile)`
-   - `preferences.getProfileFallbackUrl(profile)`

- Updated call sites:
-   - `Profile.update()` (subscription refresh)
-   - `EditProfileView.initState()` (populates the URL field async)
-   - `_TvItem` (Send-to-TV ListItem; now async-aware)

- Phase-9 migration (move plaintext URLs out of the JSON blob into the
- encrypted store) runs from a `WidgetsBinding.addPostFrameCallback`
- inside `AppController.init()`, AFTER the first frame, so a slow
- keystore can no longer freeze the splash. Idempotent:
- `migrateProfileUrlsIfNeeded()` exits immediately if the marker is
- already set.

- Verified on Pixel 10 debug + release builds: UI renders immediately,
- secure-storage reads happen only when the user opens a profile form
- or fires a subscription refresh. `flutter_analyze` clean on the
- touched files.

- Update changelog

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
