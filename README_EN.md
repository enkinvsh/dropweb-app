<div align="center">

<img src="assets/images/icon.png" alt="dropweb" width="160" />

# dropweb

**A modern VPN client for Android, Windows, macOS and Linux**

A fork of [FlClashX](https://github.com/pluralplay/FlClashX) built on the mihomo core. Custom Flutter UI, no ads, no telemetry, GPL-3.0 licensed.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**Russian**](README.md) · [Download the latest build →](https://github.com/enkinvsh/dropweb-app/releases)

</div>

---

## What dropweb adds

dropweb is a fork of [FlClashX](https://github.com/pluralplay/FlClashX). Everything FlClashX itself does keeps working. The fork has two things of its own.

### LUMINA — design system

A complete dark-first design system written from scratch specifically for dropweb. A living void background `#030305` with a mesh gradient and slowly drifting light pillars on the home screen, glass surfaces on `white 3%` with blur, bioluminescent glow on active elements — green `#15803d` bleeding into `#22c55e`. This is not a theme layered on top of Material 3 — every screen in the client has been rethought in a single visual language.

Tokens and helpers live in [`lib/common/lumina.dart`](lib/common/lumina.dart), backgrounds in [`lib/widgets/mesh_background.dart`](lib/widgets/mesh_background.dart) and [`lib/widgets/light_pillar.dart`](lib/widgets/light_pillar.dart). The full spec and the CSS → Flutter mapping sit in [`docs/plans/2026-04-06-lumina-design-system.md`](docs/plans/2026-04-06-lumina-design-system.md).

### HWID — subscription-to-device binding

The client reads a stable hardware ID from the device and passes it to the provider when fetching the subscription. If a key leaks, it cannot be used from a different phone — the provider's server sees a foreign identifier and refuses. Protection against key resale, account sharing and replay attacks with leaked subscriptions.

The behaviour is opt-in — it's enabled on the provider side, and the client sends the identifier only when the subscription panel asks for it. Nothing about the user is stored locally and nothing else leaves the device.

## Screenshots

<div align="center">

<img src="docs/screenshots/dashboard.png" width="300" alt="Dashboard" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Proxies" />

</div>

## Download

All builds are published on the [Releases page →](https://github.com/enkinvsh/dropweb-app/releases)

| Platform | File | Recommended for |
| --- | --- | --- |
| **Android (arm64)** | `dropweb-android-arm64-v8a.apk` | Most modern devices |
| **Android (universal)** | `dropweb-android-universal.apk` | When you're not sure about the architecture |
| **Windows (x64)** | `dropweb-windows-amd64-setup.exe` | Installer for Windows 10 / 11 |

> Linux, macOS and Windows ARM builds are temporarily unavailable — they will return in one of the upcoming releases.

## What's inherited from FlClashX and mihomo

From [mihomo](https://github.com/MetaCubeX/mihomo) — VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC and Remnawave-compatible subscription formats. From [FlClash](https://github.com/chen08209/FlClash) — Android TV, 120 Hz and the Russian localization base. From [FlClashX](https://github.com/pluralplay/FlClashX) — the `flclashx-*` server headers protocol (reference below) and the announcement widget. All of this works in dropweb as-is; the fork does not break any of it.

## Server headers (FlClashX protocol)

This is a protocol inherited from FlClashX. dropweb does not change it but keeps it working for compatibility with Remnawave-style subscription panels — providers can control which widgets appear on the home screen, how the app looks and how it behaves, straight from the subscription page, without having to ship a new APK.

<details>
<summary><strong>flclashx-widgets</strong> — widget order on the home screen</summary>

| Value | Widget |
| :---: | ------ |
| `announce` | Announcements |
| `networkSpeed` | Network speed |
| `outboundModeV2` | Proxy mode (new style) |
| `outboundMode` | Proxy mode (old style) |
| `trafficUsage` | Traffic usage |
| `networkDetection` | IP and location |
| `tunButton` | TUN button (Desktop) |
| `vpnButton` | VPN button (Android) |
| `systemProxyButton` | System proxy (Desktop) |
| `intranetIp` | Local IP |
| `memoryInfo` | Memory usage |
| `metainfo` | Subscription info |
| `changeServerButton` | Change server |
| `serviceInfo` | Service info |

```http
flclashx-widgets: announce,metainfo,outboundModeV2,networkDetection
```

</details>

<details>
<summary><strong>flclashx-view</strong> — proxy page appearance</summary>

| Parameter | Possible values |
| :-------: | --------------- |
| `type` | `list`, `tab` |
| `sort` | `none`, `delay`, `name` |
| `layout` | `loose`, `standard`, `tight` |
| `icon` | `none`, `icon` |
| `card` | `expand`, `shrink`, `min`, `oneline` |

```http
flclashx-view: type:list; sort:delay; layout:tight; icon:icon; card:shrink
```

</details>

<details>
<summary><strong>flclashx-hex</strong> — theme and accent color</summary>

```http
flclashx-hex: 15803d
flclashx-hex: 15803d:vibrant
flclashx-hex: 15803d:vibrant:pureblack
```

Format: `<hex>[:<variant>][:<background>]`. Variants — `tonalSpot`, `vibrant`, `expressive`, `content`, `fidelity`. Background — `pureblack` for AMOLED screens.

</details>

<details>
<summary><strong>flclashx-settings</strong> — settings via subscription</summary>

| Parameter | Description |
| :-------: | ----------- |
| `minimize` | Minimize on exit instead of closing |
| `autorun` | Launch on system startup |
| `shadowstart` | Start minimized to tray |
| `autostart` | Auto-start proxy on launch |
| `autoupdate` | Check for updates automatically |

```http
flclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate
```

</details>

<details>
<summary><strong>Other headers</strong></summary>

- `flclashx-custom: add|update` — when to apply styles (only when the subscription is added, or on every refresh)
- `flclashx-denywidgets: true` — prevent the user from editing the Dashboard
- `flclashx-servicename: Name` — service name shown in the ServiceInfo widget
- `flclashx-servicelogo: https://...` — service logo (svg or png)
- `flclashx-serverinfo: ProxyGroup` — proxy group used by the change-server widget
- `flclashx-background: https://...` — background image for the home screen
- `flclashx-globalmode: false` — hide the proxy mode switcher

</details>

## Building from source

### Requirements

- Flutter SDK ≥ 3.5.0
- Android NDK 28
- Go 1.21+ (for the mihomo core)

dropweb follows the FlClashX convention of using `setup.dart` instead of `flutter build` — the script compiles the Go core, links the native library and packages the Flutter bundle.

### Android (arm64)

```bash
dart run setup.dart android --arch arm64
```

The output APK lands at `dist/dropweb-android-arm64-v8a.apk`.

### Linux

Install the system dependencies first:

```bash
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev
```

Then:

```bash
dart run setup.dart linux --arch amd64
```

### Windows / macOS

Same pattern — see `setup.dart` for the full list of supported platforms and architectures.

## License

GPL-3.0 — see [LICENSE](LICENSE).

dropweb is a modified version of FlClashX. Original works:

- [chen08209/FlClash](https://github.com/chen08209/FlClash) — the original Flutter client
- [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX) — fork with extensions for subscription providers
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) — proxy core that powers everything

All dropweb changes are open and available in this repository under the same GPL-3.0 license.
