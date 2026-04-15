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
