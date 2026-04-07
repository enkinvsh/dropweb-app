# dropweb Full Rebrand — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate every trace of FlClashX/pluralplay/com.follow.clash branding across ALL platforms, replace with dropweb branding, fork submodules, generate icons, prepare for store release.

**Architecture:** 10 independent work streams that can execute in parallel. Each stream owns a distinct set of files with zero overlap. Streams 1-7 are pure text/asset changes. Streams 8-9 require GitHub + rebuilds. Stream 10 is signing/legal prep.

**Tech Stack:** Flutter/Dart, Kotlin, Swift, Go, Rust, Xcode, Gradle, CMake, Inno Setup

**Naming Convention:**
- App name: `dropweb`
- Package/Bundle ID: `org.dropweb.vpn`
- Kotlin classes: `Dropweb*` (e.g., `DropwebApplication`, `DropwebVpnService`)
- Dart classes: `Dropweb*` (e.g., `DropwebHttpOverrides`)
- User-Agent: `dropweb/v{version}`
- Helper service: `DropwebHelperService`
- Go core binary name: keep `FlClashCore` filename (precompiled, referenced everywhere), change internal `MihomoName` only
- macOS bundle ID: `org.dropweb.vpn`
- Copyright: `Copyright © 2025 dropweb contributors`
- Repository: `enkinvsh/dropweb-app`

**CRITICAL — DO NOT TOUCH:**
- `flclashx-*` HTTP headers (protocol with Remnawave panel) — 8 files, ~25 instances
- `chen08209/re-editor.git` and `chen08209/flutter_js` in pubspec.yaml — external deps
- `clash://` and `clashmeta://` URL schemes — keep for client compatibility alongside `dropweb://`
- `flclash://` URL scheme — keep for backward compatibility

---

## Stream 1: Dart Code Rebrand

**Owner:** Agent A
**Risk:** Low (string replacements only, no structural changes)
**Verification:** `dart analyze` clean, app compiles

### Task 1.1: Constants & Config

**Files:**
- Modify: `lib/common/constant.dart`
- Modify: `lib/common/package.dart`
- Modify: `lib/common/path.dart`

**Changes:**

`lib/common/constant.dart`:
```
Line 12: "FlClashHelperService" → "DropwebHelperService"
Line 48: "enkinvsh/FlClashX" → "enkinvsh/dropweb-app"
```

`lib/common/package.dart`:
```
Line 7: "FlClash X/v$version" → "dropweb/v$version"
```

`lib/common/path.dart`:
```
Line 42: comment — update to reflect current state
Line 45: path string — keep FlClashCore (it's the binary name), update com.follow.clash → org.dropweb.vpn
```

### Task 1.2: HTTP & Window

**Files:**
- Modify: `lib/common/http.dart`
- Modify: `lib/common/request.dart`
- Modify: `lib/common/window.dart`

**Changes:**

`lib/common/http.dart`:
```
Line 6: class FlClashHttpOverrides → class DropwebHttpOverrides
```

`lib/common/request.dart`:
```
Line 28: FlClashHttpOverrides → DropwebHttpOverrides
```

`lib/common/window.dart`:
```
Line 17: protocol.register("clashx") — KEEP (backward compat)
Line 18: protocol.register("flclash") — KEEP (backward compat)
Both already registered alongside "dropweb"
```

### Task 1.3: Main & Controller

**Files:**
- Modify: `lib/main.dart`

**Changes:**
```
Line 40: FlClashHttpOverrides → DropwebHttpOverrides
```
SKIP all `flclashx-*` header references (protocol — do not touch)

### Task 1.4: About Screen

**Files:**
- Modify: `lib/views/about.dart`

**Changes:**
```
Line 136: "https://github.com/$repository" — already uses const, will auto-update from Task 1.1
Line 144: "https://github.com/chen08209/FlClash" — KEEP (GPL attribution to original)
Line 152: "https://github.com/pluralplay/xHomo" — update to forked repo URL
```

Add new ListItem for "Source Code" linking to `https://github.com/enkinvsh/dropweb-app`
Add GPL notice text: "Based on FlClashX, licensed under GPL-3.0"

### Task 1.5: Config General

**Files:**
- Modify: `lib/views/config/general.dart`

**Changes:**
```
Line 117: "clashx-verge/v1.6.6" — this is a User-Agent preset option, KEEP as-is (it's for mimicking other clients)
```

### Task 1.6: Setup Script

**Files:**
- Modify: `setup.dart`

**Changes:**
```
Line 136: "FlClashCore" — KEEP (binary filename, must match precompiled binary)
Line 359: "FlClashHelperService" → "DropwebHelperService"
```

### Task 1.7: pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

**Changes:**
```
Line 2: description — remove "FlClash", write dropweb description
```

---

## Stream 2: Android Rebrand (Kotlin + XML)

**Owner:** Agent B
**Risk:** HIGH — file renames + manifest must be atomic. One mismatch = crash.
**Verification:** `flutter build apk --debug` succeeds, app launches on device

### Task 2.1: Rename Kotlin Files

Rename files (git mv):
```
FlClashXApplication.kt → DropwebApplication.kt
FlClashService.kt → DropwebService.kt
FlClashVpnService.kt → DropwebVpnService.kt
FlClashTileService.kt → DropwebTileService.kt
```

All in: `android/app/src/main/kotlin/org/dropweb/vpn/`
Services in: `android/app/src/main/kotlin/org/dropweb/vpn/services/`

### Task 2.2: Update Class Names in Renamed Files

**Files:**
- Modify: `DropwebApplication.kt` (was FlClashXApplication.kt)
- Modify: `DropwebService.kt` (was FlClashService.kt)
- Modify: `DropwebVpnService.kt` (was FlClashVpnService.kt)
- Modify: `DropwebTileService.kt` (was FlClashTileService.kt)

**Changes per file — EXHAUSTIVE:**

`DropwebApplication.kt`:
```kotlin
class FlClashXApplication → class DropwebApplication
private lateinit var instance: FlClashXApplication → DropwebApplication
```

`DropwebService.kt`:
```kotlin
class FlClashXService → class DropwebService
cachedBuilder = createFlClashXNotificationBuilder() → createDropwebNotificationBuilder()
fun getService(): FlClashXService = this@FlClashXService → fun getService(): DropwebService = this@DropwebService
```

`DropwebVpnService.kt`:
```kotlin
class FlClashXVpnService → class DropwebVpnService
cachedBuilder = createFlClashXNotificationBuilder() → createDropwebNotificationBuilder()
fun getService(): FlClashXVpnService = this@FlClashXVpnService → fun getService(): DropwebVpnService = this@DropwebVpnService
```

`DropwebTileService.kt`:
```kotlin
class FlClashXTileService → class DropwebTileService
TAG = "FlClashTileService" → TAG = "DropwebTileService"
```

### Task 2.3: Update References in Dependent Files

**Files:**
- Modify: `android/app/src/main/kotlin/org/dropweb/vpn/services/BaseServiceInterface.kt`
- Modify: `android/app/src/main/kotlin/org/dropweb/vpn/plugins/VpnPlugin.kt`
- Modify: `android/app/src/main/kotlin/org/dropweb/vpn/plugins/AppPlugin.kt`
- Modify: `android/app/src/main/kotlin/org/dropweb/vpn/GlobalState.kt`

**BaseServiceInterface.kt:**
```
createFlClashXNotificationBuilder → createDropwebNotificationBuilder (all 5 occurrences)
```

**VpnPlugin.kt:**
```
import FlClashXApplication → import DropwebApplication
import FlClashXService → import DropwebService
import FlClashXVpnService → import DropwebVpnService
FlClashXApplication.getAppContext() → DropwebApplication.getAppContext() (all occurrences)
is FlClashXVpnService.LocalBinder → is DropwebVpnService.LocalBinder
is FlClashXService.LocalBinder → is DropwebService.LocalBinder
FlClashXVpnService::class.java → DropwebVpnService::class.java
FlClashXService::class.java → DropwebService::class.java
(flClashXService as? FlClashXVpnService) → (dropwebService as? DropwebVpnService) — check variable name too
```

**AppPlugin.kt:**
```
import FlClashXApplication → import DropwebApplication
FlClashXApplication.getAppContext() → DropwebApplication.getAppContext() (all occurrences)
```

**GlobalState.kt:**
```
FlClashXApplication.getAppContext() → DropwebApplication.getAppContext() (2 occurrences)
```

### Task 2.4: Update AndroidManifest.xml

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/debug/AndroidManifest.xml`

**Main AndroidManifest.xml:**
```
.FlClashXApplication → .DropwebApplication
.services.FlClashXTileService → .services.DropwebTileService
.services.FlClashXVpnService → .services.DropwebVpnService
.services.FlClashXService → .services.DropwebService
```

**Debug AndroidManifest.xml:**
```
.services.FlClashXTileService → .services.DropwebTileService
```

### Task 2.5: Verify Android Build

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Stream 3: macOS Rebrand

**Owner:** Agent C
**Risk:** Medium (bundle ID change, Xcode project edits)
**Verification:** macOS project opens in Xcode without errors

### Task 3.1: Bundle ID & Copyright

**Files:**
- Modify: `macos/Runner/Configs/AppInfo.xcconfig`

**Changes:**
```
Line 11: PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash → org.dropweb.vpn
Line 14: PRODUCT_COPYRIGHT = Copyright © 2023 com.follow. All rights reserved. → Copyright © 2025 dropweb contributors. All rights reserved.
```

### Task 3.2: AppDelegate.swift

**Files:**
- Modify: `macos/Runner/AppDelegate.swift`

**Changes:**
```
Line 75: "Contents/MacOS/FlClashCore" — KEEP (binary filename)
Line 76: "com.follow.clash/cores/FlClashCore" → "org.dropweb.vpn/cores/FlClashCore"
Line 92: print("FlClashCore updated...") → print("Core binary updated...")
Line 102: print("FlClashCore already...") → print("Core binary already...")
```

### Task 3.3: Info.plist

**Files:**
- Modify: `macos/Runner/Info.plist`

**Changes:**
```
Line 31: <string>clashmeta</string> — KEEP (backward compat URL scheme)
Line 32: <string>flclash</string> — KEEP (backward compat URL scheme)
Both coexist with <string>dropweb</string>
```
No changes needed here — URL schemes already include dropweb.

### Task 3.4: MainMenu.xib

**Files:**
- Modify: `macos/Runner/Base.lproj/MainMenu.xib`

**Changes:**
```
Line 16: customModule="FlClash" → customModule="dropweb"
Line 333: customModule="FlClash" → customModule="dropweb"
```

### Task 3.5: Xcode Project

**Files:**
- Modify: `macos/Runner.xcodeproj/project.pbxproj`

**Changes:**
```
All PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash → org.dropweb.vpn (3 occurrences)
All PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash.debug → org.dropweb.vpn.debug (1 occurrence)
All PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash.RunnerTests → org.dropweb.vpn.RunnerTests (3 occurrences)
TEST_HOST FlClash.app lines (3 occurrences) → dropweb.app
FlClashCore references — KEEP (binary filename)
```

---

## Stream 4: Windows Rebrand

**Owner:** Agent D
**Risk:** Low
**Verification:** Files parseable, no syntax errors

### Task 4.1: CMakeLists.txt

**Files:**
- Modify: `windows/CMakeLists.txt`

**Changes:**
```
Line 93: FlClashCore.exe — KEEP (binary filename)
Line 96: FlClashHelperService.exe — needs rename when helper is rebuilt, for now add TODO comment
```

### Task 4.2: Inno Setup

**Files:**
- Modify: `windows/packaging/exe/inno_setup.iss`

**Changes:**
```
Line 44: 'FlClashCore.exe' — KEEP (binary filename)
Line 44: 'FlClashHelperService.exe' → TODO when helper rebuilt
Lines 103,162,176,183: 'FlClashHelperService' service name → 'DropwebHelperService'
```

### Task 4.3: Windows make_config

**Files:**
- Modify: `windows/packaging/exe/make_config.yaml`

**Changes:**
```
Line 4: publisher: pluralplay → publisher: dropweb
Line 5: publisher_url: https://github.com/pluralplay/FlClashX → https://github.com/enkinvsh/dropweb-app
```

---

## Stream 5: Linux Rebrand

**Owner:** Agent D (same as Windows — small scope)
**Risk:** Low

### Task 5.1: CMakeLists.txt

**Files:**
- Modify: `linux/CMakeLists.txt`

**Changes:**
```
Line 122: FlClashCore — KEEP (binary filename)
```

### Task 5.2: Package Configs

**Files:**
- Modify: `linux/packaging/rpm/make_config.yaml`
- Modify: `linux/packaging/deb/make_config.yaml`

**Changes:**

RPM:
```
Line 3: packager: pluralplay → packager: dropweb
Line 4: packagerEmail: mail@pluralplay.rw → (your email or info@dropweb.org)
```

DEB:
```
Line 4: name: pluralplay → name: dropweb
Line 5: email: mail@pluralplay.rw → (your email or info@dropweb.org)
```

---

## Stream 6: Assets & Icons

**Owner:** Agent E
**Risk:** Low (image generation)
**Verification:** Visual check of generated icons

### Task 6.1: Generate Adaptive Icon Foreground

**Source:** `assets/images/icon.png` (teal/gray X mark on dark bg)

**Generate:**
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png`
- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png`

**Method:** Run `flutter pub run flutter_launcher_icons` after updating `pubspec.yaml` config:
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/images/icon.png"
  adaptive_icon_background: "#202020"
  adaptive_icon_foreground: "assets/images/icon.png"
  adaptive_icon_monochrome: "assets/images/icon_white.png"
```

BUT FIRST — need to create `icon_white.png` as a proper white-on-transparent version of the X mark for monochrome icons.

### Task 6.2: Create Monochrome Icon

Create `assets/images/icon_white.png` — white X mark on transparent background, derived from icon.png.
Used for: Android 13+ themed icons, system tray.

### Task 6.3: TV Banner

**Replace:** `android/app/src/main/res/mipmap-xhdpi/ic_banner.png`

Create 320×180 banner with:
- Dark background (#202020)
- dropweb X mark logo on left
- Text "dropweb" in Unbounded font on right
- No FlClashX text

### Task 6.4: README Screenshots

**Replace:**
- `snapshots/mobile.gif` — record new LUMINA UI
- `snapshots/desktop.gif` — record new desktop UI

NOTE: This requires running app on device. DEFER to after all code changes and successful build.

---

## Stream 7: Meta & Community Files

**Owner:** Agent F
**Risk:** Low (documentation only)

### Task 7.1: README.md

**Files:**
- Rewrite: `README.md`
- Rewrite: `README_EN.md`
- Delete: `README_old.md`

**New README structure:**
```markdown
# dropweb

VPN client for Android, macOS, Windows, Linux.
Fork of [FlClashX](https://github.com/pluralplay/FlClashX) based on [FlClash](https://github.com/chen08209/FlClash) and mihomo core.

## Features
- LUMINA 2027 design system
- Custom server header support (flclashx-* protocol)
- HWID device binding
- Service announcements widget
- 120Hz display support
- Russian localization
- Android TV optimization

## Download
- Android APK: [dropweb.org/app](https://dropweb.org/app)
- Google Play: (coming soon)

## Building
(build instructions)

## License
GPL-3.0 — see [LICENSE](LICENSE)

This is a modified version of FlClashX. Original work by [chen08209](https://github.com/chen08209/FlClash) and [pluralplay](https://github.com/pluralplay/FlClashX).
```

### Task 7.2: GitHub Templates

**Files:**
- Modify: `.github/ISSUE_TEMPLATE/config.yml` — update t.me link
- Modify: `.github/ISSUE_TEMPLATE/feature_request.yml` — pluralplay/FlClashX → enkinvsh/dropweb-app
- Modify: `.github/ISSUE_TEMPLATE/bug_report.yml` — same + "FlClashX" → "dropweb"
- Modify: `.github/FUNDING.yml` — update Tribute link or remove

### Task 7.3: CI/CD Workflows

**Files:**
- Modify: `.github/workflows/build.yaml`
- Modify: `.github/workflows/macos-sign-notarize.yaml`

**build.yaml:**
```
Line 236: flclashx@pluralplay.ru → your email
Line 237: pluralplay → your git name
Lines 284,296: pluralplay/FlClashX → enkinvsh/dropweb-app
```

**macos-sign-notarize.yaml:**
```
Lines 93,125: flclash-notarization → dropweb-notarization
Line 151: FlClashX-*.dmg → dropweb-*.dmg
```

### Task 7.4: Makefile

**Files:**
- Modify: `Makefile`

**Changes:**
```
Line 25: FlClashX-*.dmg → dropweb-*.dmg
Line 27: flclash-notarization → dropweb-notarization
```

### Task 7.5: .gitmodules

**Files:**
- Modify: `.gitmodules`

**Changes:**
```
Line 3: url = git@github.com:pluralplay/flutter_distributor.git → git@github.com:enkinvsh/flutter_distributor.git
Line 4: branch = FlClash → branch = main (or dropweb)
Line 9: url = git@github.com:pluralplay/xHomo.git → git@github.com:enkinvsh/xhomo.git
Line 10: branch = FlClashX → branch = main (or dropweb)
```

---

## Stream 8: Fork & Rebuild Submodules

**Owner:** Manual (requires GitHub operations + Go/Rust build environment)
**Risk:** High (build chain)
**Prerequisite:** Must complete before final release build

### Task 8.1: Fork pluralplay/xHomo

```bash
gh repo fork pluralplay/xHomo --clone=false --org=enkinvsh
# Or: gh repo fork pluralplay/xHomo --clone=false (to personal)
```

Then in the fork, change:
- `constant/version.go:6`: `MihomoName = "FlClashX"` → `MihomoName = "dropweb"`

### Task 8.2: Fork pluralplay/flutter_distributor

```bash
gh repo fork pluralplay/flutter_distributor --clone=false --org=enkinvsh
```

No content changes needed — just ownership.

### Task 8.3: Update Submodule References

After forking:
```bash
git submodule set-url core/Clash.Meta git@github.com:enkinvsh/xhomo.git
git submodule set-url plugins/flutter_distributor git@github.com:enkinvsh/flutter_distributor.git
git submodule update --remote
```

### Task 8.4: Rebuild Go Core Binaries

After MihomoName change, rebuild:
- `libclash/android/arm64-v8a/libclash.so`
- `libclash/macos/FlClashCore`
- `libclash/windows/FlClashCore.exe`

Build command (from existing setup.dart or Makefile — check build chain).

---

## Stream 9: Rust Helper Service

**Owner:** Agent or Manual
**Risk:** Low change, medium build

### Task 9.1: Change Service Name

**Files:**
- Modify: `services/helper/src/service/windows.rs`

**Changes:**
```
Line 19: const SERVICE_NAME: &str = "FlClashHelperService" → "DropwebHelperService"
```

### Task 9.2: Rebuild Helper

Rebuild the helper binary after change. Only affects Windows.

---

## Stream 10: Signing & Store Preparation

**Owner:** Manual + Agent
**Risk:** Low

### Task 10.1: Generate Android Keystore

```bash
keytool -genkey -v -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dropweb -storepass <password> -keypass <password> \
  -dname "CN=dropweb, OU=VPN, O=dropweb, L=Moscow, ST=Moscow, C=RU"
```

Create `android/local.properties`:
```
storePassword=<password>
keyAlias=dropweb
keyPassword=<password>
```

CRITICAL: Store keystore password in vault. Lose it = can never update the app in store.

### Task 10.2: Privacy Policy Page

Create `dropweb.org/privacy` with standard VPN privacy policy:
- What data is collected (minimal — connection timestamps, bandwidth)
- What is NOT collected (browsing history, DNS queries, traffic content)
- Third-party services (Remnawave panel)
- Contact info

### Task 10.3: About Screen — GPL Compliance

Ensure `lib/views/about.dart` has:
- Link to source code: `github.com/enkinvsh/dropweb-app`
- Original project attribution (FlClash by chen08209)
- GPL-3.0 license notice
- Link to privacy policy
- "This is a modified version" notice (GPL 5a requirement)

---

## Task Dependency Graph

```
Stream 1 (Dart)          ──┐
Stream 2 (Kotlin+XML)    ──┤
Stream 3 (macOS)         ──┤── Wave 1 (all independent, zero deps)
Stream 4+5 (Win+Linux)   ──┤
Stream 6 (Icons)         ──┤
Stream 7 (Meta)          ──┘
                            │
                            ▼
Stream 8 (Submodule forks) ─┤── Wave 2 (needs .gitmodules from S7, forks need GitHub)
Stream 9 (Rust helper)    ─┘
                            │
                            ▼
Stream 10 (Signing+Legal) ──┤── Wave 3 (needs all code done)
Verification + Build      ──┘
```

**Dependency reasons:**
- Wave 1 streams touch ZERO overlapping files — fully parallel
- Wave 2: Stream 8 needs .gitmodules written by Stream 7; Stream 9 can run with Wave 1 but rebuild needs build env
- Wave 3: Keystore + build verification needs all code changes landed

---

## Parallel Execution Graph

### Wave 1 — Fire ALL simultaneously (no dependencies)

| Task ID | Stream | Category | Skills | Files | QA Command |
|---------|--------|----------|--------|-------|------------|
| W1-A | Stream 1: Dart rebrand | `quick` | `[]` | 8 dart files + setup.dart + pubspec.yaml | `dart analyze lib/` |
| W1-B | Stream 2: Kotlin + Android XML | `deep` | `["systematic-debugging"]` | 8 .kt files (4 renamed) + 2 .xml | `cd android && ./gradlew assembleDebug` |
| W1-C | Stream 3: macOS rebrand | `unspecified-high` | `[]` | 5 files (xcconfig, swift, plist, xib, pbxproj) | `grep -ri "com.follow" macos/` returns 0 hits |
| W1-D | Stream 4+5: Windows + Linux | `quick` | `[]` | 6 files (cmake, iss, yaml) | `grep -ri "pluralplay" windows/ linux/` returns 0 hits |
| W1-E | Stream 6: Icons | `visual-engineering` | `["frontend-design"]` | icon_white.png, ic_launcher_foreground, ic_banner | Visual inspection of generated PNGs |
| W1-F | Stream 7: Meta + Community | `writing` | `["dropweb-writer"]` | README×2, .github/×6, Makefile, .gitmodules, pubspec | `grep -ri "pluralplay" README.md .github/ Makefile` returns 0 hits |

### Wave 2 — After Wave 1 completes

| Task ID | Stream | Category | Skills | Depends On | QA Command |
|---------|--------|----------|--------|------------|------------|
| W2-A | Stream 8: Fork submodules | MANUAL | — | W1-F (.gitmodules) | Verify forks exist on GitHub, submodule update succeeds |
| W2-B | Stream 9: Rust helper | `quick` | `[]` | None (independent) | `grep "FlClashHelperService" services/` returns 0 hits |

### Wave 3 — Final verification

| Task ID | Stream | Category | Skills | Depends On | QA Command |
|---------|--------|----------|--------|------------|------------|
| W3-A | Stream 10: Signing + legal | MANUAL | — | All Waves | Keystore exists, privacy policy URL resolves |
| W3-B | Full build | `deep` | `["verification-before-completion"]` | All Waves | `dart run setup.dart android --arch arm64` exit code 0 |
| W3-C | Branding audit | `quick` | `[]` | W3-B | All grep checks pass (see Verification Checklist) |

---

## TODO List (Structured for Agent Dispatch)

### Wave 1 — Parallel Dispatch

```
W1-A: Dart Code Rebrand
  What: Replace FlClash* class names, constants, User-Agent in 8 dart files + setup.dart + pubspec.yaml
  Depends: nothing
  Blocks: W3-B (build)
  Category: quick
  Skills: []
  QA: dart analyze lib/ — zero errors. grep -rn "FlClashHttpOverrides\|enkinvsh/FlClashX\|FlClash X/v" lib/ setup.dart — zero hits
  MUST NOT: touch flclashx-* HTTP headers (protocol), touch chen08209 git deps, rename FlClashCore binary references

W1-B: Android Kotlin + XML Rebrand
  What: Rename 4 .kt files (git mv), update all class names + imports + AndroidManifest references
  Depends: nothing
  Blocks: W3-B (build)
  Category: deep
  Skills: ["systematic-debugging"]
  QA: grep -rn "FlClashX\|FlClashService\|FlClashVpn\|FlClashTile" android/ — only hits in flclashx-* protocol comments. App compiles.
  MUST NOT: break AndroidManifest ↔ Kotlin class name mapping. Every android:name must match actual class.
  CRITICAL: File renames + class renames + manifest updates = ONE ATOMIC COMMIT

W1-C: macOS Rebrand
  What: Change bundle ID com.follow.clash → org.dropweb.vpn, update copyright, xib customModule, pbxproj identifiers
  Depends: nothing
  Blocks: W3-B (build)
  Category: unspecified-high
  Skills: []
  QA: grep -rn "com.follow" macos/ — zero hits. grep -rn "customModule=\"FlClash\"" macos/ — zero hits.
  MUST NOT: change FlClashCore binary filename references (keep as-is), remove backward-compat URL schemes

W1-D: Windows + Linux Rebrand
  What: Update publisher/packager info in make_config.yaml files, update service names in inno_setup.iss
  Depends: nothing
  Blocks: nothing (non-critical platforms)
  Category: quick
  Skills: []
  QA: grep -rn "pluralplay" windows/ linux/ — zero hits
  MUST NOT: change FlClashCore.exe binary filename (it's precompiled)

W1-E: Icon Generation
  What: Generate adaptive icon foreground + monochrome icon from assets/images/icon.png, create TV banner
  Depends: nothing
  Blocks: W3-B (build includes icons)
  Category: visual-engineering
  Skills: ["frontend-design"]
  QA: All icon PNGs exist at correct paths. ic_launcher_foreground.png is NOT the FlClashX cat. ic_banner.png has "dropweb" text.
  NOTE: icon_white.png already EXISTS at assets/images/ but is blank/transparent — needs proper content

W1-F: Meta & Community Files
  What: Rewrite README (RU+EN), update GitHub templates, CI workflows, Makefile, .gitmodules, delete README_old.md
  Depends: nothing
  Blocks: W2-A (submodule URLs)
  Category: writing
  Skills: ["dropweb-writer"]
  QA: grep -rn "pluralplay\|FlClashX" README.md README_EN.md .github/ Makefile — zero hits (except GPL attribution)
  MUST NOT: remove GPL attribution to original FlClash/FlClashX authors
```

### Wave 2 — After Wave 1

```
W2-A: Fork Submodules (MANUAL)
  What: Fork pluralplay/xHomo and pluralplay/flutter_distributor to enkinvsh/, change MihomoName in Go core
  Depends: W1-F (.gitmodules URLs)
  Blocks: W3-B (final build with correct core)
  Category: MANUAL — requires GitHub web/CLI operations + Go build environment
  QA: gh repo view enkinvsh/xhomo succeeds. git submodule update --remote succeeds.

W2-B: Rust Helper Service Name
  What: Change SERVICE_NAME in services/helper/src/service/windows.rs
  Depends: nothing
  Blocks: nothing (Windows-only, rebuild needed separately)
  Category: quick
  Skills: []
  QA: grep "FlClashHelperService" services/ — zero hits
```

### Wave 3 — Final

```
W3-A: Signing & Legal (MANUAL)
  What: Generate keystore, create privacy policy page, store password in vault
  Depends: all code changes
  Blocks: release build
  Category: MANUAL
  QA: keystore.jks exists, local.properties has credentials, privacy policy URL resolves

W3-B: Full Build Verification
  What: Build Android APK, verify all branding correct
  Depends: W1-A through W2-B
  Blocks: release
  Category: deep
  Skills: ["verification-before-completion"]
  QA: dart run setup.dart android --arch arm64 — exit code 0. APK installs and launches.

W3-C: Branding Audit
  What: Final grep sweep for any remaining FlClash/pluralplay/com.follow references
  Depends: W3-B
  Blocks: release
  Category: quick
  Skills: []
  QA: see Verification Checklist below — all checks pass
```

---

## Verification Checklist

After ALL waves complete:

- [ ] `dart analyze` — no errors
- [ ] `grep -ri "FlClash" lib/ android/ macos/ windows/ linux/ services/ --include="*.dart" --include="*.kt" --include="*.xml" --include="*.swift" --include="*.xcconfig" --include="*.xib" --include="*.yaml" --include="*.yml" --include="*.iss" --include="*.rs" --include="*.md"` — only hits are: protocol headers (flclashx-*), backward-compat URL schemes, chen08209 deps, binary filenames (FlClashCore), GPL attribution link, clashx-verge UA preset
- [ ] `grep -ri "pluralplay" .` — ZERO hits (except git history)
- [ ] `grep -ri "com.follow.clash" .` — ZERO hits
- [ ] Android debug build succeeds
- [ ] Android release build succeeds (with keystore)
- [ ] App launches and connects
- [ ] Adaptive icon shows dropweb, not cat
- [ ] Quick Settings tile shows "dropweb"
- [ ] Notification shows "dropweb"
- [ ] About screen shows correct links
- [ ] User-Agent in network requests shows "dropweb/v..."
