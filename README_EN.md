<img src="assets/images/header.png" alt="dropweb" width="720" />

# dropweb

**A modern VPN client for Android, Windows, macOS and Linux**

A fork of [FlClashX](https://github.com/pluralplay/FlClashX) built on the mihomo core. Custom Flutter UI, no ads, no telemetry, GPL-3.0 licensed.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**Russian**](README.md) · [Download the latest build →](https://github.com/enkinvsh/dropweb-app/releases)

---

## What dropweb adds

dropweb is a fork of [FlClashX](https://github.com/pluralplay/FlClashX). Everything FlClashX itself does keeps working. The fork has two things of its own.

### LUMINA — design system

A complete dark-first design system written from scratch specifically for dropweb. A living void background `#030305` with a mesh gradient and slowly drifting light pillars on the home screen, glass surfaces on `white 3%` with blur, bioluminescent glow on active elements — green `#15803d` bleeding into `#22c55e`. This is not a theme layered on top of Material 3 — every screen in the client has been rethought in a single visual language.

### Localhost API hardening

The mihomo core exposes an HTTP API on localhost for proxy control — unprotected, any process on the device could reach it and drive the VPN: switch servers, rewrite the config, snoop traffic. dropweb generates a random 64-character secret at every launch and sets it as the mihomo `external-controller` secret. Without it the API returns 401 to every request. The secret lives in memory only for the current session — it is never persisted and never transmitted anywhere.

## Screenshots

<img src="docs/screenshots/dashboard.png" width="300" alt="Dashboard" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Proxies" />

## License

GPL-3.0 — see [LICENSE](LICENSE). All dropweb changes are open in this repository.

The fork builds on the work of others: [FlClashX](https://github.com/pluralplay/FlClashX) → [FlClash](https://github.com/chen08209/FlClash) → [mihomo](https://github.com/MetaCubeX/mihomo).
