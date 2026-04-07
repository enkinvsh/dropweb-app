<div align="center">

# dropweb

VPN client for Android, macOS, Windows, Linux

A fork of [FlClashX](https://github.com/pluralplay/FlClashX) based on [FlClash](https://github.com/chen08209/FlClash) and the mihomo core.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&logo=github)](https://github.com/enkinvsh/dropweb-app/releases/)

[**Russian**](README.md)

</div>

## Features

- 🎨 LUMINA 2027 — custom design system with glass surfaces and mesh gradients
- 🔐 Server header support (flclashx-* protocol)
- 📱 HWID device binding
- 📢 Provider announcement widget
- 🖥️ 120Hz display support
- 🇷🇺 Full Russian localization
- 📺 Android TV optimization
- 🧹 No ads, open source

## Download

- [APK for Android](https://dropweb.org/app)
- Google Play — coming soon

## Server Headers

The app supports custom subscription headers for controlling widgets, appearance, and settings.

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

```bash
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

```bash
flclashx-view: type:list; sort:delay; layout:tight; icon:icon; card:shrink
```
</details>

<details>
<summary><strong>flclashx-hex</strong> — theme and accent color</summary>

```bash
flclashx-hex: 15803d
flclashx-hex: 15803d:vibrant
flclashx-hex: 15803d:vibrant:pureblack
```
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

```bash
flclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate
```
</details>

<details>
<summary><strong>Other headers</strong></summary>

- `flclashx-custom: add|update` — when to apply styles (on add or every update)
- `flclashx-denywidgets: true` — prevent Dashboard editing
- `flclashx-servicename: Name` — service name in ServiceInfo widget
- `flclashx-servicelogo: https://...` — service logo (svg/png)
- `flclashx-serverinfo: ProxyGroup` — group for the change server widget
- `flclashx-background: https://...` — background image
- `flclashx-globalmode: false` — hide proxy mode switcher
</details>

## Build

### Requirements

- Flutter SDK >=3.5.0
- Android NDK 28
- Go (for the core)

### Android

```bash
dart run setup.dart android --arch arm64
```

Output APK: `dist/dropweb-android-arm64-v8a.apk`

### Linux

Install dependencies before building:

```bash
sudo apt-get install libayatana-appindicator3-dev
sudo apt-get install libkeybinder-3.0-dev
```

## License

GPL-3.0 — see [LICENSE](LICENSE)

This is a modified version of FlClashX. Original work by [chen08209/FlClash](https://github.com/chen08209/FlClash) and [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX).
