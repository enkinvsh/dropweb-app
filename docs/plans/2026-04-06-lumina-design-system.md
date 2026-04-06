# LUMINA Design System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply LUMINA 2027 design system to dropweb-app — void background with mesh gradient, deep glass surfaces, bioluminescent glow on interactive elements, animated light pillar background on Home screen.

**Architecture:** LUMINA is a dark-first glass-surface design language. The void (`#030305`) is alive — mesh gradients and animated light pillars give depth. Surfaces are near-invisible glass (`white 3%`) with blur and specular borders (`white 8%`). Active elements glow with accent-colored shadows. All values adapted from the CSS reference to Flutter equivalents.

**Tech Stack:** Flutter, Material 3, CustomPainter (for mesh/pillar backgrounds), BackdropFilter (for glass surfaces), Riverpod (state management)

**Reference:** LUMINA CSS from `/Users/oen/Downloads/Telegram Desktop/index (12).html`, dropweb color palette from zencab (`#15803d` accent)

**LUMINA → Dropweb Palette Mapping:**
| LUMINA token | LUMINA value | Dropweb adaptation |
|---|---|---|
| `--bg-dark` | `#030305` | `#030305` (keep as-is, slight blue tint) |
| `--glass-surface` | `rgba(255,255,255, 0.03)` | same |
| `--glass-border` | `rgba(255,255,255, 0.08)` | same |
| `--glow-primary` | `#5b50e6` (purple) | `#15803d` (dropweb green) |
| `--glow-secondary` | `#ffbe98` (peach) | `#22c55e` (light green) |
| `--glow-accent` | `#38bdf8` (blue) | `#38bdf8` (keep blue as secondary accent) |

**CSS → Flutter Mapping:**
| CSS | Flutter |
|---|---|
| `blur(20px)` | `ImageFilter.blur(sigmaX: 10, sigmaY: 10)` |
| `blur(60px)` (mesh) | `ImageFilter.blur(sigmaX: 30, sigmaY: 30)` |
| `saturate(120%)` | `ColorFilter` or skip (not natively supported in BackdropFilter) |
| `rgba(255,255,255, 0.03)` | `Colors.white.withOpacity(0.03)` |
| `transition 0.4s cubic-bezier(0.2, 0.8, 0.2, 1)` | `Duration(milliseconds: 400)`, `Cubic(0.2, 0.8, 0.2, 1.0)` |
| `box-shadow: 0 20px 40px rgba(0,0,0,0.2)` | `BoxShadow(offset: Offset(0,10), blurRadius: 20, color: black20)` |

---

### Task 1: LUMINA Theme Foundation

**Files:**
- Modify: `lib/application.dart` — `_buildThemeData` method
- Modify: `lib/common/color.dart` — `toPureBlack` extension
- Create: `lib/common/lumina.dart` — LUMINA design tokens as constants

**Step 1: Create LUMINA design tokens file**

```dart
// lib/common/lumina.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// LUMINA 2027 Design System tokens for dropweb
class Lumina {
  Lumina._();

  // Void background — NOT pure black, slight blue tint
  static const Color void_ = Color(0xFF030305);

  // Surface hierarchy — from void to barely visible
  static const Color surface1 = Color(0xFF060608);
  static const Color surface2 = Color(0xFF0A0A0D);
  static const Color surface3 = Color(0xFF0F0F12);
  static const Color surface4 = Color(0xFF141417);
  static const Color surface5 = Color(0xFF1A1A1D);

  // Glass
  static const double glassOpacity = 0.03;
  static const double glassBorderOpacity = 0.08;
  static const double glassHoverOpacity = 0.06;
  static const double glassHoverBorderOpacity = 0.15;

  // Blur — CSS 20px ≈ Flutter sigma 10
  static const double blurSigma = 10.0;
  static const double blurSigmaHeavy = 16.0;

  // Glow colors (adapted for dropweb)
  static const Color glowPrimary = Color(0xFF15803D);   // dropweb green
  static const Color glowSecondary = Color(0xFF22C55E);  // light green
  static const Color glowAccent = Color(0xFF38BDF8);     // blue (from LUMINA)

  // Shadows
  static const List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Color(0x33000000), // black 20%
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> glassDeepShadow = [
    BoxShadow(
      color: Color(0x4D000000), // black 30%
      blurRadius: 30,
      offset: Offset(0, 15),
    ),
  ];

  // Radii
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusXxl = 48.0;

  // Animation curve — LUMINA easing
  static const Curve luminaCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Duration luminaDuration = Duration(milliseconds: 400);

  // Glass decoration helper
  static BoxDecoration glass({
    double opacity = glassOpacity,
    double borderOpacity = glassBorderOpacity,
    double radius = radiusXl,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(borderOpacity),
        width: 1,
      ),
      boxShadow: shadow ?? glassShadow,
    );
  }

  // Glow shadow for active elements
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: 16,
        spreadRadius: 2,
      ),
    ];
  }

  // Mesh gradient colors for background
  static const List<MeshGradientSpot> meshSpots = [];
}
```

**Step 2: Update `_buildThemeData` in `application.dart`**

Replace surface overrides with Lumina tokens. Use `Lumina.void_` as base surface, `Lumina.surface1-5` for container hierarchy. Apply to both dark theme AND ensure light theme stays clean (Material 3 defaults).

**Step 3: Update `toPureBlack` in `color.dart`**

Currently only overrides 2 properties. Expand to use full Lumina surface hierarchy when enabled.

**Step 4: Verify build**

Run: `flutter analyze` — 0 errors.

**Step 5: Commit**

```
feat(theme): add LUMINA design tokens and void surface hierarchy
```

---

### Task 2: Mesh Gradient Background

**Files:**
- Create: `lib/widgets/mesh_background.dart` — CustomPainter for mesh gradient
- Modify: `lib/widgets/scaffold.dart` — add mesh background layer behind content
- Modify: `lib/pages/home.dart` — enable mesh bg on dashboard

**Step 1: Create MeshBackground widget**

A `CustomPainter` that draws three radial gradients (adapted LUMINA mesh):
- Top-left: `glowPrimary` at 10% opacity
- Top-right: `glowSecondary` at 8% opacity  
- Bottom-right: `glowAccent` at 10% opacity

Wrapped in `RepaintBoundary` + `ImageFiltered(blur: sigma 30)` for the mesh blur effect.

Static — no animation. Cheap to render. Cached by RepaintBoundary.

**Step 2: Add to scaffold as background layer**

In `CommonScaffold.build()`, add mesh gradient as bottom layer in the existing Stack (below body, above background image if any). Only render on dark theme.

**Step 3: Verify build and test visually**

Run: `flutter analyze` — 0 errors.

**Step 4: Commit**

```
feat(ui): add LUMINA mesh gradient background
```

---

### Task 3: Animated Light Pillar Background (Home only)

**Files:**
- Create: `lib/widgets/light_pillar.dart` — animated vertical light beams
- Modify: `lib/views/dashboard/dashboard.dart` — add pillar bg behind dashboard content

**Step 1: Create LightPillar widget**

`CustomPainter` with `AnimationController` that draws 3-5 soft vertical light beams:
- Semi-transparent (`3-5% white`)
- Varying widths (40-120px)
- Slow vertical drift animation (30-60s cycle) 
- Gaussian-like horizontal fade
- `RepaintBoundary` wrapped

Performance: only on Home screen, low opacity, simple geometry.

**Step 2: Place behind dashboard content**

In `DashboardView`, wrap content in `Stack` with `LightPillar` as bottom layer.

**Step 3: Verify build**

Run: `flutter analyze` — 0 errors.

**Step 4: Commit**

```
feat(ui): add animated light pillar background on Home screen
```

---

### Task 4: Glass Tab Bar (LUMINA spec)

**Files:**
- Modify: `lib/pages/home.dart` — `CommonNavigationBar` mobile section + `_buildConnectCircle`

**Step 1: Update tab bar to exact LUMINA glass values**

Replace current values with Lumina tokens:
- Background: `Lumina.glass()` decoration
- Blur: `Lumina.blurSigma` (sigma 10)
- Shadow: `Lumina.glassShadow`
- Keep `RepaintBoundary`

**Step 2: Update connect circle to exact LUMINA glass values**

Same glass treatment. When active (VPN on):
- Add `Lumina.glowShadow(colorScheme.primary)` — green glow
- Icon color: `colorScheme.primary`
- Subtle border brightening (`glassBorderOpacity` → `glassHoverBorderOpacity`)

**Step 3: Verify build**

Run: `flutter analyze` — 0 errors.

**Step 4: Commit**

```
feat(ui): LUMINA glass treatment for tab bar and connect button
```

---

### Task 5: Glass Dashboard Widgets

**Files:**
- Modify: `lib/views/dashboard/widgets/` — subscription_info, change_server_button, and other widget cards
- Modify: `lib/application.dart` — CardTheme in `_buildThemeData`

**Step 1: Update CardTheme to LUMINA glass**

Use `Lumina.glass()` for card decoration in dark theme. This cascades to all cards app-wide.

**Step 2: Check key dashboard widgets render correctly**

Verify `metainfo` (subscription card), `changeServerButton` (server selector) look correct with glass styling. Fix any text readability issues (ensure text stays `white/85%` or brighter on glass).

**Step 3: Verify build**

Run: `flutter analyze` — 0 errors.

**Step 4: Commit**

```
feat(ui): LUMINA glass cards for dashboard widgets
```

---

### Task 6: Bioluminescent Active States

**Files:**
- Modify: `lib/views/dashboard/widgets/start_button.dart` — glow on active
- Modify: `lib/pages/home.dart` — tab bar selected item glow

**Step 1: Connect button glow**

When VPN is connected:
- `BoxShadow` with `glowPrimary` at 40% opacity, blur 16, spread 2
- Icon glows (primary color)
- Glass border brightens to `glassHoverBorderOpacity`
- Breathe animation (optional): `AnimationController` pulsing shadow intensity between 20%-50% over 3s

**Step 2: Tab bar active item glow**

Selected tab icon gets a subtle dot or underline glow in `glowPrimary`.

**Step 3: Verify build**

Run: `flutter analyze` — 0 errors.

**Step 4: Commit**

```
feat(ui): bioluminescent glow on connect button and tab bar active states
```

---

### Task 7: Polish & Light Theme

**Files:**
- Modify: `lib/application.dart` — light theme adjustments
- Modify: `lib/pages/home.dart` — conditional glass for light/dark

**Step 1: Light theme**

Light theme should NOT use glass (glass is void-native). Instead:
- White/light surfaces with subtle shadows
- No blur (cheap)
- Accent color still `#15803d`
- Cards: white bg, subtle gray border, standard elevation

**Step 2: Conditional rendering**

Tab bar, connect button: check `Theme.of(context).brightness` — use glass on dark, solid on light.

**Step 3: Final build and full visual check**

Build APK, test both themes on device.

**Step 4: Commit**

```
feat(ui): LUMINA light theme fallback, conditional glass rendering
```

---

### Task 8: Final Commit & Cleanup

**Step 1: Remove old/unused code**

- Remove `_NavigationBarDefaultsM3` class if unused
- Clean up any dead code from previous iterations

**Step 2: Save design doc to memory**

Update `design/lumina-2027-system` memory doc with final Flutter mappings.

**Step 3: Git push**

```bash
git add -A
git commit -m "chore: cleanup LUMINA implementation, remove dead code"
git push
```
