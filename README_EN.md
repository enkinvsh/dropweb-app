<div align="center">

<img src="assets/images/icon.png" alt="dropweb" width="160" />

# dropweb

**A modern VPN client for Android, Windows, macOS and Linux**

A fork of [FlClashX](https://github.com/pluralplay/FlClashX) built on the mihomo core. Custom Flutter UI, no ads, no telemetry, GPL-3.0 licensed.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**Russian**](README.md) · [Download the latest build →](https://github.com/enkinvsh/dropweb-app/releases/latest)

</div>

---

## Features

- 🎨 **LUMINA 2027** — a custom design system with glass surfaces, mesh gradients and neon iconography
- 🔐 **Server headers** — the `flclashx-*` protocol lets your provider control widgets, theme and behaviour straight from the subscription page
- 📡 **Mihomo under the hood** — supports VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC and Remnawave-compatible subscription formats
- 📱 **HWID device binding** — the app always knows where it's running
- 📢 **Announcement widget** — providers can post messages directly to the dashboard
- 🖥️ **120 Hz** — high-refresh display support on Android
- 📺 **Android TV** — optimised for D-pad navigation and large screens
- 🇷🇺 **Full Russian localization** — native, not machine-translated
- 🧹 **No ads**, no telemetry, fully open source

## Screenshots

<div align="center">

<img src="docs/screenshots/dashboard.png" width="300" alt="Dashboard" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Proxies" />

</div>

## Download

All builds are published on the [Releases page →](https://github.com/enkinvsh/dropweb-app/releases/latest)

| Platform | File | Recommended for |
| --- | --- | --- |
| **Android (arm64)** | `dropweb-android-arm64-v8a.apk` | Most modern devices |
| **Android (universal)** | `dropweb-android-universal.apk` | When you're not sure about the architecture |
| **Windows (x64)** | `dropweb-windows-amd64-setup.exe` | Installer for Windows 10 / 11 |

> Linux, macOS and Windows ARM builds are temporarily unavailable — they will return in one of the upcoming releases.

## Server headers

dropweb supports custom HTTP headers on the subscription page. Providers can use them to control which widgets appear on the home screen, how the app looks and how it behaves — without having to ship a new APK. Especially convenient for subscription panels built on [Remnawave](https://remna.st) and similar.

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
