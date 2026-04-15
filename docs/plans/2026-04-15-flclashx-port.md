# FlClashX Feature Port Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port remaining features from pluralplay/FlClashX to dropweb-app

**Architecture:** Minimal diffs — most Remnawave features already ported. Focus on VPN stability fixes, search UI, and TIER 2/3 features.

**Tech Stack:** Flutter/Dart, Kotlin (Android), Riverpod state management

---

## Status Summary

### ✅ Already Ported (no action needed)
- Subscription expiry notifications (`lib/services/subscription_notification_service.dart`)
- Russian localization (`arb/intl_ru.arb` — 469 strings)
- Remnawave headers: `flclashx-widgets`, `flclashx-hex`, `flclashx-view`, `flclashx-globalmode`
- Dashboard widget parser (`DashboardWidgetParser.parseLayout`)
- Proxies search backend (query filtering in `lib/views/proxies/list.dart:96`)

### 🔧 Remaining Work

---

## Task 1: VPN Include/Exclude Package Priority Fix

**Priority:** HIGH  
**Risk:** LOW (additive change)  
**Upstream commit:** a4b131b

**Files:**
- Modify: `android/app/src/main/kotlin/app/dropweb/models/Props.kt`
- Modify: `android/app/src/main/kotlin/app/dropweb/services/DropwebVpnService.kt`

### Step 1: Add includePackage/excludePackage to VpnOptions

Edit `Props.kt` to add nullable fields:

```kotlin
data class VpnOptions(
    val enable: Boolean,
    val port: Int,
    val accessControl: AccessControl,
    val allowBypass: Boolean,
    val systemProxy: Boolean,
    val bypassDomain: List<String>,
    val routeAddress: List<String>,
    val ipv4Address: String,
    val ipv6Address: String,
    val dnsServerAddress: String,
    val includePackage: List<String>? = null,  // NEW
    val excludePackage: List<String>? = null,  // NEW
)
```

### Step 2: Update VPN service with priority logic

Replace access control block in `DropwebVpnService.kt` (around line 96-113):

```kotlin
addDnsServer(options.dnsServerAddress)
setMtu(9000)  // Changed from 1500

// Profile-level tun.include-package / tun.exclude-package take
// precedence over the app-level access control
val include = options.includePackage.orEmpty()
val exclude = options.excludePackage.orEmpty()
when {
    include.isNotEmpty() -> {
        (include + packageName).distinct().forEach { pkg ->
            try {
                addAllowedApplication(pkg)
            } catch (_: Exception) {
                Log.d("VpnService", "addAllowedApplication failed: $pkg")
            }
        }
    }
    exclude.isNotEmpty() -> {
        (exclude - packageName).forEach { pkg ->
            try {
                addDisallowedApplication(pkg)
            } catch (_: Exception) {
                Log.d("VpnService", "addDisallowedApplication failed: $pkg")
            }
        }
    }
    else -> options.accessControl.let { accessControl ->
        if (accessControl.enable) {
            when (accessControl.mode) {
                AccessControlMode.acceptSelected -> {
                    (accessControl.acceptList + packageName).forEach {
                        try {
                            addAllowedApplication(it)
                        } catch (_: Exception) {
                            Log.d("VpnService", "addAllowedApplication failed: $it")
                        }
                    }
                }
                AccessControlMode.rejectSelected -> {
                    (accessControl.rejectList - packageName).forEach {
                        try {
                            addDisallowedApplication(it)
                        } catch (_: Exception) {
                            Log.d("VpnService", "addDisallowedApplication failed: $it")
                        }
                    }
                }
            }
        }
    }
}
```

### Step 3: Update Dart VPN plugin to pass new fields

Check if `lib/plugins/vpn.dart` needs to serialize includePackage/excludePackage from profile config.

### Step 4: Verify

```bash
cd /Users/oen/Documents/projects/dropweb-app
dart run setup.dart android --arch arm64
# Install and test VPN connection
```

### Step 5: Commit

```bash
git add android/app/src/main/kotlin/app/dropweb/models/Props.kt \
        android/app/src/main/kotlin/app/dropweb/services/DropwebVpnService.kt
git commit -m "fix(android): VPN include/exclude package priority + MTU 9000"
```

---

## Task 2: Proxies Search UI

**Priority:** HIGH  
**Risk:** LOW (UI addition only)  

**Files:**
- Modify: `lib/views/proxies/proxies.dart` (add SearchBar)
- Modify: `lib/views/proxies/list.dart` (wire up query state)
- Modify: `lib/providers/state.dart` (add search query provider if needed)

### Step 1: Add search query provider

Check if `proxiesSearchQueryProvider` exists. If not, add to `lib/providers/app.dart`:

```dart
final proxiesSearchQueryProvider = StateProvider<String>((ref) => '');
```

### Step 2: Add SearchBar to ProxiesView

In `lib/views/proxies/proxies.dart`, add search field:

```dart
@override
List<Widget> get actions => [
  Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Consumer(
        builder: (context, ref, _) => TextField(
          decoration: InputDecoration(
            hintText: appLocalizations.search,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onChanged: (value) {
            ref.read(proxiesSearchQueryProvider.notifier).state = value.toLowerCase();
          },
        ),
      ),
    ),
  ),
];
```

### Step 3: Wire ProxiesListView to query

Ensure `ProxiesListView` reads from the provider:

```dart
final query = ref.watch(proxiesSearchQueryProvider);
// Pass to _buildItems(query: query)
```

### Step 4: Verify via hot reload

```bash
flutter_run
# Navigate to Proxies tab, test search
flutter_screenshot
```

### Step 5: Commit

```bash
git add lib/views/proxies/proxies.dart lib/providers/app.dart
git commit -m "feat(ui): add proxies search bar"
```

---

## Task 3: Dashboard Remake (TIER 2)

**Priority:** MEDIUM  
**Risk:** MEDIUM (UI rework)  

Compare upstream `lib/views/dashboard/dashboard.dart` against ours. Key changes:
- Layout improvements
- Widget sizing
- Animation polish

**Action:** Create visual comparison first. Screenshots of both, identify deltas.

---

## Task 4: DNS/Hosts Override (TIER 2)

**Priority:** MEDIUM  

**Upstream files:**
- `lib/views/config/dns.dart` — DNS override UI
- `lib/models/config.dart` — DNS override model

**Action:** Compare and port UI components.

---

## Task 5: macOS Status Bar (TIER 3)

**Priority:** LOW  
**Platform:** macOS only

**Upstream files:**
- `lib/manager/status_bar_manager.dart`
- `macos/Runner/StatusBarController.swift`

**Action:** Port if macOS becomes priority.

---

## Task 6: Android TV D-pad Fixes (TIER 3)

**Priority:** LOW  
**Platform:** Android TV only

**Upstream commit:** 3d628fc

**Action:** Port focus handling improvements if TV is target.

---

## Task 7: Custom Text Scaling (TIER 3)

**Priority:** LOW  

**Action:** Port `textScaleFactor` setting from upstream settings.

---

## Execution Order

1. **Task 1** — VPN fixes (critical path, affects stability)
2. **Task 2** — Proxies search UI (quick win, high visibility)
3. **Task 3-7** — As needed based on priorities

---

## Reference Commits (pluralplay/FlClashX)

| Feature | Commit |
|---------|--------|
| VPN include/exclude | a4b131b |
| Android TV fixes | 3d628fc |
| Latency check all groups | 5a8b7bb |
| macOS status bar | a000acb |
| HWID notifications | 1d9c2dc |

---

## Verification Checklist

After each task:
- [ ] `flutter_analyze` — 0 errors
- [ ] `flutter_build` — APK builds successfully
- [ ] Manual test on Pixel 10
- [ ] No regressions in existing functionality
