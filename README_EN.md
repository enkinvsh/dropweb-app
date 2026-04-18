<div align="right">
  <a href="README.md">Русский</a>
</div>

<img src="assets/images/header.png" alt="dropweb — VPN proxy client mihomo Clash Meta for Android Windows macOS with anti-detection" width="720" />

# dropweb

<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Latest Release">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb-app?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
</a>

<br>

<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download for Android">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Download for Windows">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS">
</a>

---

Cross-platform proxy client powered by [mihomo](https://github.com/MetaCubeX/mihomo) (Clash Meta) core. Fork of [FlClashX](https://github.com/pluralplay/FlClashX) focused on local scanning protection, DPI bypass and utilitarian interface.

Built for a specific task: give engineers a tool they can deploy to non-technical users (or use themselves) for stable access to international services, without detection risks or broken configs.

## Download

- [Android](https://github.com/enkinvsh/dropweb-app/releases) — APK, 6.0+
- [Windows](https://github.com/enkinvsh/dropweb-app/releases) — Portable/Setup, 10+
- [macOS](https://github.com/enkinvsh/dropweb-app/releases) — DMG, 11+ (Intel and Apple Silicon)

## Features

- **Protocols:** VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard (Xray-core compatible)
- **Subscriptions:** Import via URL/QR, auto-update in background
- **Routing:** Split tunneling — local traffic direct, blocked through proxy (GeoIP/Geosite)
- **UI:** Stripped down to essentials, only necessary controls

---

## Why Fork and Detection Protection

FlClashX is an excellent client, but most popular apps (Happ, v2rayNG, Hiddify, Neko Box) are vulnerable to local scanning. Any app on the device can find the standard SOCKS port (7890) without root — this is actively used for VPN user detection.

**How dropweb solves this:**

- **Dynamic ports** — randomization instead of default 7890/7891
- **SOCKS authentication** — enforced, scanners can't verify traffic type
- **TUN only** — removed system proxy (readable from OS settings), all routing via virtual interface

---

## Build from Source

```bash
git clone https://github.com/enkinvsh/dropweb-app.git
cd dropweb-app
flutter pub get

# Android
dart run setup.dart android --arch arm64

# Windows  
dart run setup.dart windows

# macOS
dart run setup.dart macos
```

Requires Flutter SDK 3.24+. Mihomo binaries are downloaded automatically.

---

## Known Issues

- **Android:** Aggressive battery optimization (MIUI, ColorOS) may kill VPN in background. Disable battery optimization for dropweb
- **macOS:** First launch requires admin rights for TUN interface
- **Old devices:** Android with <3GB RAM may crash with heavy GeoIP databases

---

## License

GPL-3.0 — see [LICENSE](LICENSE).

**Links:** [FlClashX — parent fork](https://github.com/pluralplay/FlClashX) · [FlClash — original](https://github.com/chen08209/FlClash)

---

<sub>This tool is designed for personal traffic security and information access.<br>User assumes responsibility for compliance with local laws.</sub>
