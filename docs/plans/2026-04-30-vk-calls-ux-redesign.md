# VK Calls UX Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. After every visible UI phase, hand control back for live phone correction. Never batch phases.

**Goal:** Reshape the ParazitX page (`lib/views/parazitx_page.dart`) into a calm, banking-grade "VK Звонки" stability screen following Direction A "Тихий оператор", without changing any tunnel/auth/manifest logic and without exposing internal transport terminology.

**Architecture:** Pure UI/copy refactor inside the existing `ParazitXPage` Stack. Status mapping (`_mapStatus`) is widened from 4 buckets to 7 user-facing states (idle, syncing, verification, connecting, ready, rotation heartbeat, error) but still derives from the same `VkTunnelPlugin.statusStream` strings. The current handoff overlay, safety timer, navigation pop, and `ParazitXManager` callsites remain byte-identical. Visual layout switches to: AppBar "VK Звонки" → hero state card → primary CTA → collapsible "Параметры соединения" → info link → footer diagnostics. No new packages, no new providers, no new files outside `lib/views/parazitx/` (sub-widgets only).

**Tech Stack:** Flutter (Material 3, existing theme), Dart, Riverpod (read-only), existing `VkTunnelPlugin`, existing `ParazitXManager`, existing `TunnelStatus` constants, existing `LogBuffer`. No new dependencies. Impeller flag and Android package `org.dropweb.vpn` MUST NOT be touched.

---

## Hard Constraints (apply to every phase)

**Forbidden words anywhere in user-visible UI** (visible Text, Tooltip, SnackBar, semanticsLabel, dialog body, button label):

```
обход, блокировки, белые списки, цензура, ТСПУ, маскировка, запреты,
bypass, unblock, evade, censorship, allowlist, whitelist, throttle, DPI
```

**Allowed user-facing lexicon** (these are the only ways to describe the feature in copy):

```
VK Звонки
режим стабильности
локальный VPN-канал
параметры соединения
резервный маршрут
синхронизация
проверка доступа
обновление маршрута
```

**Internal terms that MUST NOT appear in default UI** (only allowed inside the collapsed "Параметры соединения" diagnostics block, and only when the user explicitly expands it):

```
ParazitX, relay, manifest, signaling, captcha, rotation, tunnel,
librelay, mihomo, proxy, profile, subscription
```

**Visual rules (Direction A — "Тихий оператор"):**
- Pure surface, no glow, no neon, no cyberpunk, no hacker grid.
- No shield / lock / globe / VPN / padlock / radar icons as hero.
- Hero element is a rounded soft card with a single status dot and a short human sentence.
- Single accent: VK blue (`#0077FF` family from existing theme — do NOT introduce a new color constant; reuse `Theme.of(context).colorScheme.primary` if it already maps to VK blue, otherwise use a single `const Color(0xFF0077FF)` defined locally inside the new file).
- Typography: existing theme text styles only. No new font weights below `w400` or above `w700`.
- Motion: `AnimatedSwitcher` 200ms, `AnimatedContainer` 200ms. No bounce, no shake, no flashy transitions.
- One primary CTA button, full-width, rounded 12-16px, label changes per state (see Phase 2 copy table). No secondary buttons in default view.

**Logic rules:**
- `VkTunnelPlugin.statusStream` listener stays as-is.
- `ParazitXManager.isTunnelReady` check in `initState` stays as-is.
- `_handoffSafetyBudget`, `_handoffNavigationDelay`, `_scheduleHandoff`, `_showHandoffOverlay`, `_hideHandoffOverlay` stay byte-identical.
- `Navigator.of(context).popUntil` and `globalState.appController.toPage(PageLabel.dashboard)` stay byte-identical.
- `ParazitXSectionItem` keeps the same activation behavior — we wrap or re-skin it, never replace its `onTap`/activation logic.
- No edits to `lib/services/parazitx_manager.dart`, `lib/plugins/vk_tunnel_plugin.dart`, `lib/widgets/`, or anything outside `lib/views/parazitx_page.dart` and a new `lib/views/parazitx/` directory.

**Verification gates (run after every phase, before handing back to user):**

```
flutter_analyze                # 0 errors required, baseline warnings/infos OK
flutter_reload(type='restart') # always restart, this page mutates state
flutter_screenshot             # save the result, show user
```

Then grep the changed file for forbidden words:

```
Grep("обход|блокировк|белые списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx_page.dart")
```

Expected: zero matches.

---

## Phase 0 — Pre-flight, Pixel 10 live mirror

### Task 0.1: Confirm device + start live session

**Files:** none modified.

**Step 1: Verify Pixel 10 visible to ADB**

Run: `flutter_devices`
Expected: at least one entry with `state=device` and `model` matching the Pixel 10 (or whatever the user's connected handset reports).

**Step 2: Start live Flutter session**

Run: `flutter_run`
Expected: tmux session `flutter-dev` starts. Wait 30-60s. Then `flutter_pane` reports state=`ready`.

**Step 3: Capture baseline screenshot of current ParazitX page**

Action plan (do not script the navigation if the user is already on it):
1. Tell the user: "open ParazitX tab on the phone."
2. Run: `flutter_screenshot`
3. Save the returned image as the "before" reference. Mention it in the response back to user.

**Step 4: Confirm verification baseline**

Run: `flutter_analyze`
Expected: 0 errors. Note the warning/info baseline numbers (e.g. "19 warnings, 636 infos") in the response — this is the budget. Phases must not regress past this baseline.

**Step 5: Hand back to user**

No code changed. Stop. Wait for user to say "go phase 1" before any UI edit.

---

## Phase 1 — Direction A skeleton, copy and layout only

Goal: rebuild `lib/views/parazitx_page.dart`'s build method into the new shell — AppBar "VK Звонки", hero state card (rounded surface, status dot, short sentence), full-width primary CTA wrapping the existing `ParazitXSectionItem` activation, collapsed "Параметры соединения", info link, footer diagnostics — using ONLY the four existing buckets (`idle`, `connecting`, `protected`, `error`). State expansion comes in Phase 2. Hot reload must show the new layout cleanly before any logic widening.

### Task 1.1: Extract sub-widgets into `lib/views/parazitx/`

**Files:**
- Create: `lib/views/parazitx/hero_state_card.dart`
- Create: `lib/views/parazitx/primary_cta.dart`
- Create: `lib/views/parazitx/connection_details_panel.dart`
- Create: `lib/views/parazitx/footer_diagnostics.dart`
- Modify: `lib/views/parazitx_page.dart` (replace body, keep state class + handoff overlay)

**Step 1: Plan the file split on paper before editing**

Do NOT touch code yet. Read the existing `parazitx_page.dart` end to end. Confirm:
- `_StatusView`, `_mapStatus`, `_ParazitXPageState`, `_buildHandoffOverlay` stay in `parazitx_page.dart`.
- The four new files are pure presentational `StatelessWidget`s. They take a `_StatusView`-equivalent (or a new public `VkCallsState` enum — see Task 1.2) and a `VoidCallback onActivate`. They own zero state and zero side effects.

**Step 2: Create `lib/views/parazitx/hero_state_card.dart` — STUB**

Minimal stub so imports compile. Contents:

```dart
import 'package:flutter/material.dart';

import 'vk_calls_state.dart';

/// Direction A "Тихий оператор" hero card.
/// Rounded soft surface, status dot, single short Russian sentence.
/// No icons, no glow, no decoration beyond the surface tint.
class HeroStateCard extends StatelessWidget {
  const HeroStateCard({super.key, required this.state, required this.headline, required this.detail});

  final VkCallsState state;
  final String headline;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = state.accentColor(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    headline,
                    key: ValueKey<String>('vk-calls-headline:$headline'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
```

**Step 3: Create `lib/views/parazitx/vk_calls_state.dart`**

Defines the public state enum and accent-color resolver used by every sub-widget. Phase 1 only wires four cases; Phase 2 adds the remaining three.

```dart
import 'package:flutter/material.dart';

/// User-facing VK Calls states. Internal tunnel phases collapse into these.
/// Strictly NOT named after VPN/proxy/relay terms — copy is "stability mode".
enum VkCallsState {
  idle,
  connecting,
  protected,
  error,
  // Phase 2 will add: syncing, verification, rotationHeartbeat
}

extension VkCallsStateAccent on VkCallsState {
  Color accentColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (this) {
      case VkCallsState.idle:
        return cs.outline;
      case VkCallsState.connecting:
        return cs.tertiary; // amber-ish in M3 dark
      case VkCallsState.protected:
        return cs.primary; // VK blue
      case VkCallsState.error:
        return cs.error;
    }
  }
}
```

**Step 4: Create `lib/views/parazitx/primary_cta.dart`**

Full-width rounded CTA. The `onTap` is forwarded to the underlying `ParazitXSectionItem` activation by routing through `parazitx_page.dart` — see Task 1.3.

```dart
import 'package:flutter/material.dart';

import 'vk_calls_state.dart';

class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.state,
    required this.label,
    required this.onPressed,
  });

  final VkCallsState state;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null ||
        state == VkCallsState.connecting ||
        state == VkCallsState.protected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            textStyle: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
```

**Step 5: Create `lib/views/parazitx/connection_details_panel.dart`**

Collapsed by default. When expanded, shows the user-safe technical line ("Резервный маршрут активен", "Обновление маршрута через 5 мин") plus internal labels (relay region, manifest age) ONLY if the user expanded it. Phase 1 contains the panel shell — content widening happens in Phase 2.

```dart
import 'package:flutter/material.dart';

class ConnectionDetailsPanel extends StatelessWidget {
  const ConnectionDetailsPanel({super.key, required this.lines});

  /// Plain-language lines. Order matters: first is most informative.
  /// Empty list -> panel hidden.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Theme(
        // Strip ExpansionTile divider noise
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainerHigh,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(
                'Параметры соединения',
                style: theme.textTheme.titleSmall,
              ),
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 6: Create `lib/views/parazitx/footer_diagnostics.dart`**

Tiny grey footer line at the bottom. Holds session id / build hash for support — never status-relevant copy. Phase 1 puts a single neutral line here ("Версия приложения: <version>") and we wire build metadata in Phase 2.

```dart
import 'package:flutter/material.dart';

class FooterDiagnostics extends StatelessWidget {
  const FooterDiagnostics({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        line,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
```

**Step 7: Run analyzer**

Run: `flutter_analyze`
Expected: 0 errors. If new files have unused-import warnings, ignore — they get used in Task 1.3.

**Step 8: Commit reminder**

NOT this session. Plan rule: Sisyphus does not commit; orchestrator handles commits.

### Task 1.2: Add status-to-state mapping shim (still 4 buckets)

**Files:**
- Modify: `lib/views/parazitx_page.dart` (extend `_mapStatus` to also return a `VkCallsState`).

**Step 1: Add a new internal record type next to `_StatusView`**

```dart
@immutable
class _StatusView {
  const _StatusView({
    required this.state,
    required this.headline,
    required this.detail,
    required this.ctaLabel,
    required this.detailsLines,
    required this.showProgress,
  });

  final VkCallsState state;
  final String headline;
  final String? detail;
  final String ctaLabel;
  final List<String> detailsLines;
  final bool showProgress;
}
```

**Step 2: Replace `_mapStatus` body**

Phase 1 still emits exactly 4 states (`idle`, `connecting`, `protected`, `error`) but uses the new copy table:

| Internal | state | headline | detail | ctaLabel |
|---|---|---|---|---|
| empty / `disconnected` / `TunnelStatus.ready` | `idle` | "Готово к запуску" | "Включите режим стабильности для VK Звонков" | "Включить режим стабильности" |
| any progress phase except captcha and ready | `connecting` | "Подключаем режим стабильности" | "Это занимает 5-15 секунд" | "Подключение..." |
| captcha (`CAPTCHA:` / contains "captcha") | `connecting` | "Проверка доступа" | "Подтверждаем сессию VK" | "Подключение..." |
| `TunnelStatus.isTunnelReady(status)` | `protected` | "Режим стабильности активен" | "VK Звонки используют локальный VPN-канал" | "Режим стабильности активен" |
| `TunnelStatus.isFailure(status)` | `error` | "Не удалось включить режим" | (server message, sanitised) | "Повторить" |

```dart
_StatusView _mapStatus(String status) {
  if (TunnelStatus.isFailure(status)) {
    final raw = status.startsWith('ERROR:')
        ? status.substring('ERROR:'.length).trim()
        : '';
    final sanitised = _sanitiseErrorMessage(raw);
    return _StatusView(
      state: VkCallsState.error,
      headline: 'Не удалось включить режим',
      detail: sanitised.isEmpty
          ? 'Попробуйте ещё раз через минуту.'
          : sanitised,
      ctaLabel: 'Повторить',
      detailsLines: const [],
      showProgress: false,
    );
  }
  if (TunnelStatus.isTunnelReady(status)) {
    return const _StatusView(
      state: VkCallsState.protected,
      headline: 'Режим стабильности активен',
      detail: 'VK Звонки используют локальный VPN-канал.',
      ctaLabel: 'Режим стабильности активен',
      detailsLines: <String>[
        'Локальный VPN-канал: активен',
        'Резервный маршрут: подключён',
      ],
      showProgress: false,
    );
  }
  if (status.startsWith('CAPTCHA:') ||
      status.toLowerCase().contains('captcha')) {
    return const _StatusView(
      state: VkCallsState.connecting,
      headline: 'Проверка доступа',
      detail: 'Подтверждаем сессию VK.',
      ctaLabel: 'Подключение...',
      detailsLines: <String>[],
      showProgress: true,
    );
  }
  if (status.isEmpty ||
      status == TunnelStatus.ready ||
      status == 'disconnected') {
    return const _StatusView(
      state: VkCallsState.idle,
      headline: 'Готово к запуску',
      detail: 'Включите режим стабильности для VK Звонков.',
      ctaLabel: 'Включить режим стабильности',
      detailsLines: <String>[],
      showProgress: false,
    );
  }
  return const _StatusView(
    state: VkCallsState.connecting,
    headline: 'Подключаем режим стабильности',
    detail: 'Это занимает 5-15 секунд.',
    ctaLabel: 'Подключение...',
    detailsLines: <String>[],
    showProgress: true,
  );
}

/// Strip internal jargon out of server error strings before showing to user.
/// We replace any forbidden token with a neutral phrase. Anything containing
/// 'parazit', 'relay', 'manifest', 'tunnel', 'proxy' is collapsed entirely
/// to a generic message — the user does not need transport vocabulary.
String _sanitiseErrorMessage(String raw) {
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  const internalTokens = <String>[
    'parazit', 'relay', 'manifest', 'tunnel', 'proxy', 'librelay',
    'mihomo', 'signaling', 'subscription', 'profile',
  ];
  for (final t in internalTokens) {
    if (lower.contains(t)) {
      return 'Не удалось подключить режим стабильности.';
    }
  }
  return raw;
}
```

**Step 3: Run analyzer**

Run: `flutter_analyze`
Expected: 0 errors.

### Task 1.3: Replace the page body

**Files:**
- Modify: `lib/views/parazitx_page.dart`

**Step 1: Update imports**

Add to top of file:

```dart
import 'package:dropweb/views/parazitx/connection_details_panel.dart';
import 'package:dropweb/views/parazitx/footer_diagnostics.dart';
import 'package:dropweb/views/parazitx/hero_state_card.dart';
import 'package:dropweb/views/parazitx/primary_cta.dart';
import 'package:dropweb/views/parazitx/vk_calls_state.dart';
```

Remove the now-unused import of `application_setting.dart` if it was only there for the section item. Keep `widgets.dart` (we still need `ParazitXSectionItem` for the underlying activation tap).

**Step 2: Replace `build(...)` body**

```dart
@override
Widget build(BuildContext context) {
  final view = _mapStatus(_rawStatus);
  return Scaffold(
    appBar: AppBar(title: const Text('VK Звонки')),
    body: Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroStateCard(
                state: view.state,
                headline: view.headline,
                detail: view.detail,
              ),
              _ActivationGate(
                ctaLabel: view.ctaLabel,
                state: view.state,
              ),
              ConnectionDetailsPanel(lines: view.detailsLines),
              const SizedBox(height: 8),
              _LearnMoreLink(),
              const FooterDiagnostics(
                line: 'Подробнее о режиме стабильности — в настройках.',
              ),
            ],
          ),
        ),
        _buildHandoffOverlay(context),
      ],
    ),
  );
}
```

**Step 3: Add `_ActivationGate` private widget**

The CTA must call `ParazitXSectionItem`'s existing activation. We do NOT replace `ParazitXSectionItem` — we render it offscreen as a `Visibility(maintainState: true, visible: false, ...)` and let the user-visible CTA forward taps to it via a `GlobalKey<State>`.

Actually no — the cleaner path: read the activation method `ParazitXSectionItem` exposes. If it's a `StatelessWidget` with `onTap`, we instead call the same underlying manager method directly. **Implementer must inspect `lib/widgets/widgets.dart`** to find the public entry point — most likely `ParazitXManager.instance.activate()` or similar.

Conservative default if uncertain:

```dart
class _ActivationGate extends StatelessWidget {
  const _ActivationGate({required this.ctaLabel, required this.state});

  final String ctaLabel;
  final VkCallsState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Offscreen, but built — keeps existing onTap wiring intact.
        // SizedBox.shrink() with Offstage hides the visuals while
        // letting us trigger it via a GlobalKey (see _PrimaryCtaProxy).
        const Offstage(
          offstage: true,
          child: ParazitXSectionItem(),
        ),
        // Visible CTA. We call ParazitXSectionItem's activation by tapping
        // through a transparent InkWell over the offstage tree — but the
        // simpler proven path is to invoke the manager directly. The
        // implementer MUST replace the body of _onPressed below with the
        // exact activation call once it inspects ParazitXSectionItem.
        PrimaryCta(
          state: state,
          label: ctaLabel,
          onPressed: () => _onPressed(context),
        ),
      ],
    );
  }

  void _onPressed(BuildContext context) {
    // TODO(implementer): wire to the same call ParazitXSectionItem.onTap
    // makes today. Inspect lib/widgets/parazitx_section_item.dart (or
    // wherever ParazitXSectionItem lives — search via Grep for the class
    // name) and route to its public activation method.
    //
    // Likely candidate: ParazitXManager.instance.start() — confirm before
    // calling. Until verified, this stays a no-op so we never silently
    // break activation in production.
  }
}
```

**Implementer note:** Before leaving Phase 1, replace the TODO with the verified activation call. If the verified call is non-trivial (more than one line), pull `ParazitXSectionItem` apart in a Phase 1.5 task and route the activation through a shared static method. Do NOT duplicate auth flow.

**Step 4: Add `_LearnMoreLink`**

```dart
class _LearnMoreLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            // Phase 1: no-op. Phase 3 wires this to a help sheet.
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Подробнее о режиме стабильности',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 5: Delete the now-orphan `_ConnectionStatusBanner`**

Remove the entire `_ConnectionStatusBanner` class from the bottom of the file. The hero card replaces it.

**Step 6: Forbidden-words grep**

Run: `Grep("обход|блокировк|белые\\s*списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx_page.dart")`

Expected: zero matches. If anything matches, rewrite the offending copy.

**Step 7: Run analyzer**

Run: `flutter_analyze`
Expected: 0 errors.

**Step 8: Hot restart and screenshot**

Run: `flutter_reload(type='restart')`
Then ask user: "open ParazitX tab on the phone."
Run: `flutter_screenshot`
Compare to Phase 0 baseline. Expected diffs:
- AppBar reads "VK Звонки".
- Single rounded soft card at top with status dot and "Готово к запуску" / "Включите режим стабильности для VK Звонков".
- Full-width VK-blue button with "Включить режим стабильности".
- Collapsed "Параметры соединения" accordion (or hidden if `detailsLines` empty — Phase 1 hides it for idle).
- Grey "Подробнее о режиме стабильности" link.
- Faint footer line.

**Step 9: Hand back to user**

Stop. Write a short message: "Phase 1 done — Direction A skeleton on screen. Take a look on the phone, tell me which copy/spacing/contrast to adjust before I widen the state machine in Phase 2." Wait for user feedback.

---

## Phase 2 — State machine widening (idle → 7 states)

Goal: split the `connecting` bucket into the four sub-phases the user actually wants to see — `syncing`, `verification`, `connecting`, `rotationHeartbeat` — and wire the `protected` panel to show real connection details (sanitised). No layout changes; only `_mapStatus` widening, `VkCallsState` enum extension, copy table updates, and `detailsLines` content.

### Task 2.1: Extend `VkCallsState` enum

**Files:**
- Modify: `lib/views/parazitx/vk_calls_state.dart`

**Step 1: Add three cases**

```dart
enum VkCallsState {
  idle,
  syncing,            // pulling user/profile from VK after activation
  verification,       // captcha / extra check
  connecting,         // tunnel coming up
  protected,          // tunnel ready, calls work
  rotationHeartbeat,  // periodic 8-min route refresh, still protected
  error,
}
```

**Step 2: Update accent colors**

Add cases for `syncing`, `verification`, `rotationHeartbeat`. `syncing` and `connecting` share `cs.tertiary`. `verification` uses `cs.secondary`. `rotationHeartbeat` uses `cs.primary` (same as protected — user is still protected, just with a subtle pulse).

**Step 3: Run analyzer**

Run: `flutter_analyze`
Expected: 0 errors. Any switch over `VkCallsState` will fail-fast on missing cases — that's the whole point.

### Task 2.2: Widen `_mapStatus`

**Files:**
- Modify: `lib/views/parazitx_page.dart`

**Step 1: Decide phase boundaries**

Before editing, the implementer MUST grep `VkTunnelPlugin.statusStream` raw strings — search:

```
Grep("Getting|Auth|Fetching|Captcha|Resolving|Connecting|TUNNEL_CONNECTED|ROTATION", path="lib/services/parazitx_manager.dart")
```

and the same query against `lib/plugins/vk_tunnel_plugin.dart` and `lib/clash/`. Map every observed phase string to one of the seven states. If a phase doesn't fit, fall back to `connecting`.

Suggested mapping (verify against actual emitted strings):

| Raw status fragment | state | headline | detail | cta |
|---|---|---|---|---|
| `Getting anonymous token`, `Auth complete`, `Fetching config`, `Resolving subscription` | `syncing` | "Синхронизация" | "Проверяем профиль VK." | "Подключение..." |
| `CAPTCHA:`, contains `captcha`, `Captcha solved` | `verification` | "Проверка доступа" | "Подтверждаем сессию VK." | "Подключение..." |
| `CONNECTING`, `Connecting`, anything else progress-shaped | `connecting` | "Подключаем режим стабильности" | "Это занимает 5-15 секунд." | "Подключение..." |
| `isTunnelReady` AND last status was rotation heartbeat | `rotationHeartbeat` | "Обновление маршрута" | "Сохраняем стабильность звонка." | "Режим стабильности активен" |
| `isTunnelReady` (default) | `protected` | "Режим стабильности активен" | "VK Звонки используют локальный VPN-канал." | "Режим стабильности активен" |
| `isFailure` | `error` | "Не удалось включить режим" | sanitised | "Повторить" |
| empty / `disconnected` / `TunnelStatus.ready` | `idle` | "Готово к запуску" | "Включите режим стабильности для VK Звонков." | "Включить режим стабильности" |

**Step 2: Implement the widened mapping**

Replace the body of `_mapStatus` with a switch over fragment matches in the order above. Keep the helper `_sanitiseErrorMessage` from Phase 1.

**Step 3: Wire `detailsLines` for protected and rotationHeartbeat**

Implementer reads `ParazitXManager` for any public getters like `currentRegion`, `manifestRefreshAt`, `nextRotationAt` (search via `Grep` — do NOT add new getters in this phase). For each available signal, emit a sanitised line:

| Source | Sanitised line |
|---|---|
| current region | "Резервный маршрут: <region>" |
| manifest age | "Параметры обновлены: N мин назад" |
| next rotation | "Следующая синхронизация: ~N мин" |

If the manager exposes nothing useful, fall back to:

```dart
detailsLines: const <String>[
  'Локальный VPN-канал: активен',
  'Резервный маршрут: подключён',
],
```

NEVER expose region codes, relay IPs, manifest URLs, or subscription identifiers in default lines. Those go in Phase 3 (footer diagnostics on long-press only).

**Step 4: Track rotation heartbeat**

`rotationHeartbeat` is a transient state — when a status string indicating rotation arrives WHILE `_tunnelReached == true`, the page should briefly (<= 1.5s) show `rotationHeartbeat`, then return to `protected`. Implementation pattern:

```dart
String _activePhase = ''; // last non-rotation status
Timer? _rotationDecayTimer;

void _onStatus(String status) {
  // existing body...
  if (TunnelStatus.isTunnelReady(status) && _isRotationFragment(status)) {
    _rotationDecayTimer?.cancel();
    _rotationDecayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _rawStatus = TunnelStatus.tunnelConnected);
    });
  }
}
```

`_isRotationFragment` matches strings like `ROTATION`, `Rotating`, `Refresh route`. Confirm against actual emitted vocabulary before committing.

**Step 5: Run analyzer**

Run: `flutter_analyze`
Expected: 0 errors.

### Task 2.3: Verify visually on Pixel 10

**Step 1: Hot restart**

Run: `flutter_reload(type='restart')`

**Step 2: Walk all states with the user**

Tell the user: "I will trigger each state. Confirm the headline + accent + CTA copy on each before we move on."

Sequence:
1. Idle (default after fresh launch). `flutter_screenshot`.
2. Tap CTA. Capture `syncing`. `flutter_screenshot` immediately.
3. If captcha appears, capture `verification`. `flutter_screenshot`.
4. Capture `connecting` (just before tunnel ready). `flutter_screenshot`.
5. Capture `protected` (steady state). `flutter_screenshot`.
6. Wait ~8 minutes (or trigger rotation manually if a debug hook exists) and capture `rotationHeartbeat`. `flutter_screenshot`.
7. Force `error` by toggling airplane mode briefly. `flutter_screenshot`.

Do NOT proceed to Phase 3 until the user signs off on every state.

**Step 3: Forbidden-words grep on the whole `lib/views/parazitx/` tree + `parazitx_page.dart`**

Run:
```
Grep("обход|блокировк|белые\\s*списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx_page.dart")
Grep("обход|блокировк|белые\\s*списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx")
```

Expected: zero matches in both.

**Step 4: Hand back to user**

Stop. Wait for user to confirm or request copy adjustments.

---

## Phase 3 — Information architecture polish

Goal: wire "Подробнее о режиме стабильности" link to a help bottom sheet, surface real diagnostics in `FooterDiagnostics` (build hash / session id, long-press to copy), and add accessibility semantics. No new states, no logic changes.

### Task 3.1: Help bottom sheet

**Files:**
- Create: `lib/views/parazitx/stability_help_sheet.dart`
- Modify: `lib/views/parazitx_page.dart` (wire `_LearnMoreLink.onPressed`)

**Step 1: Create the sheet**

Plain Material `showModalBottomSheet`. Content is three short paragraphs + a primary "Понятно" button. Copy:

> **Что такое режим стабильности**
>
> Режим стабильности — это локальный VPN-канал, который улучшает качество VK Звонков на вашем устройстве. При его включении соединение становится более устойчивым, помехи и обрывы случаются реже.
>
> **Когда он нужен**
>
> Включайте режим, если звонки в VK прерываются, плохо слышно собеседника или видео тормозит.
>
> **Что произойдёт после включения**
>
> Появится системный значок VPN. Это нормально — приложение использует локальный канал только для своих сетевых обращений. Другие приложения работают как обычно.

No mention of bypass, blocking, censorship, ISPs, regions, governments, jurisdictions. If the user (or product) requests legal text, it goes in a separate "Условия" link, not here.

**Step 2: Wire the link**

```dart
onPressed: () => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  builder: (_) => const StabilityHelpSheet(),
),
```

**Step 3: Run analyzer + screenshot the sheet**

Run: `flutter_analyze` → 0 errors.
Run: `flutter_reload(type='reload')` (sheet is presentational, hot reload OK).
Tell user: "tap 'Подробнее о режиме стабильности' on the phone."
Run: `flutter_screenshot` after sheet opens.

### Task 3.2: Real footer diagnostics

**Files:**
- Modify: `lib/views/parazitx_page.dart` (compose footer line from build metadata)
- Modify: `lib/views/parazitx/footer_diagnostics.dart` (add long-press copy-to-clipboard)

**Step 1: Compose footer line**

Pull from existing globals (do NOT add new ones). Likely sources to grep first:
- `Grep("packageInfo|appVersion|buildNumber", path="lib")` to find existing version surface.
- `LogBuffer.instance` for session id if it already exists.

Format:

```
Версия 1.4.2 · Сборка 4321
```

If session id is available append `· Сессия #abcd1234`. Never append region, IP, relay name, manifest hash.

**Step 2: Long-press copies to clipboard**

```dart
GestureDetector(
  onLongPress: () {
    Clipboard.setData(ClipboardData(text: line));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано')),
    );
  },
  child: Text(line, ...),
)
```

This is for support — users send the footer to support; support reads version + build + session.

**Step 3: Run analyzer + screenshot**

Run: `flutter_analyze` → 0 errors.
Run: `flutter_reload(type='reload')`.
Run: `flutter_screenshot`.
Ask user to long-press footer; verify SnackBar appears.

### Task 3.3: Accessibility pass

**Files:**
- Modify: `lib/views/parazitx/hero_state_card.dart`, `lib/views/parazitx/primary_cta.dart`

**Step 1: Wrap hero card in `Semantics`**

```dart
Semantics(
  container: true,
  label: '$headline. ${detail ?? ''}',
  liveRegion: true,
  child: Container(...),
)
```

`liveRegion: true` makes TalkBack announce the state change (idle → connecting → protected) automatically.

**Step 2: CTA accessible label**

Already covered by `FilledButton`'s child Text, but add explicit `Semantics(button: true, enabled: !disabled, label: label, child: ...)` for clarity.

**Step 3: Run analyzer**

Run: `flutter_analyze` → 0 errors.

**Step 4: Manual TalkBack smoke test**

Tell user: "enable TalkBack in Android settings, swipe through the screen, confirm headline + CTA are read out and that state changes are announced." Optional but recommended.

---

## Phase 4 — Final verification gate (before user sign-off)

Goal: prove no regressions, no forbidden vocabulary, no new dependencies.

### Task 4.1: Static checks

**Step 1: Analyzer baseline**

Run: `flutter_analyze`
Expected: 0 errors. Warning/info count must equal Phase 0 baseline. If higher, fix the regression before sign-off.

**Step 2: Forbidden-words grep across the changed surface**

Run:
```
Grep("обход|блокировк|белые\\s*списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx_page.dart")
Grep("обход|блокировк|белые\\s*списк|цензур|ТСПУ|маскировк|запрет|bypass|unblock|evade|censor|allowlist|whitelist|throttle|DPI", path="lib/views/parazitx")
```

Expected: zero matches.

**Step 3: Internal terms must NOT appear in default user copy**

Default user copy lives in: `parazitx_page.dart` headlines/details/cta labels, `hero_state_card.dart`, `primary_cta.dart`, `footer_diagnostics.dart`. The collapsed `connection_details_panel.dart` and `stability_help_sheet.dart` are user-opt-in and may use a slightly broader vocabulary.

Run:
```
Grep("ParazitX|relay|manifest|signaling|captcha|rotation|tunnel|librelay|mihomo|proxy|subscription", path="lib/views/parazitx/hero_state_card.dart")
Grep("ParazitX|relay|manifest|signaling|captcha|rotation|tunnel|librelay|mihomo|proxy|subscription", path="lib/views/parazitx/primary_cta.dart")
Grep("ParazitX|relay|manifest|signaling|captcha|rotation|tunnel|librelay|mihomo|proxy|subscription", path="lib/views/parazitx/footer_diagnostics.dart")
```

Expected: zero matches in copy. Code-level identifiers are exempt — we are scanning visible string literals only. If the grep flags an identifier (e.g. `import` lines), confirm by reading the file that no string literal uses the term.

**Step 4: No new dependencies**

Run: `git diff pubspec.yaml`
Expected: empty diff. If non-empty, revert.

**Step 5: Impeller flag and Android package not touched**

Run:
```
git diff android/app/src/main/AndroidManifest.xml
git diff android/app/build.gradle
```

Expected: both empty.

### Task 4.2: Live verification

**Step 1: Cold start**

Run: `flutter_app_restart(clear_data=True)`

**Step 2: Walk every state once more**

Same sequence as Task 2.3 step 2. `flutter_screenshot` at each state. Save into the response so user has a final gallery.

**Step 3: Sign-off prompt**

Tell user:

> Phases 1-4 done. Diagnostics: 0 analyzer errors, no forbidden vocabulary in user copy, no internal jargon in default UI, no new dependencies, Impeller and Android package untouched. Screenshots above. Confirm sign-off or list adjustments.

Stop. Do not commit. Do not proceed to anything else without orchestrator instruction.

---

## Out of scope (explicit non-goals)

- Editing `lib/services/parazitx_manager.dart`, `lib/plugins/vk_tunnel_plugin.dart`, or any non-UI code.
- Changing the activation contract of `ParazitXSectionItem`. We re-skin its trigger; we do not refactor it.
- Replacing the handoff overlay (the `_buildHandoffOverlay` Stack child stays byte-identical).
- Touching `AndroidManifest.xml`, `Impeller`, the `org.dropweb.vpn` package, signing config, or anything in `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `libclash/`, `core/`, `shaders/`.
- Adding any new package in `pubspec.yaml`.
- Implementing dark/light mode toggling beyond what the existing theme already does.
- Localising into other languages — Russian only, since current user-facing copy is Russian.
- Onboarding flow, settings flow, or any tab other than `ParazitXPage`.

## Done criteria (orchestrator verifies)

- [ ] `docs/plans/2026-04-30-vk-calls-ux-redesign.md` exists (this file).
- [ ] No code under `lib/` modified by the planning step itself.
- [ ] User has signed off on every screenshot in Phase 4.
- [ ] `flutter_analyze` reports 0 errors and warning/info count is at-or-below Phase 0 baseline.
- [ ] All forbidden words grep checks return zero matches against visible copy.
- [ ] `git diff pubspec.yaml`, `git diff android/app/src/main/AndroidManifest.xml`, `git diff android/app/build.gradle` are empty.
