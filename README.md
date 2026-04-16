<div align="right">
  <a href="README_EN.md">English</a>
</div>

<img src="assets/images/header.png" alt="dropweb — прокси клиент для Android Windows macOS" width="720" />

# dropweb

<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release" alt="Latest Release">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/stargazers">
  <img src="https://img.shields.io/github/stars/enkinvsh/dropweb-app?style=for-the-badge&color=15803D&labelColor=0D1117" alt="GitHub Stars">
</a>

<br>

<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Скачать для Android">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Скачать для Windows">
</a>
<a href="https://github.com/enkinvsh/dropweb-app/releases">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Скачать для macOS">
</a>

---

Кроссплатформенный прокси-клиент на базе ядра [mihomo](https://github.com/MetaCubeX/mihomo). Форк [FlClashX](https://github.com/chen08209/FlClash) с фокусом на защиту от локального сканирования и утилитарный интерфейс.

Создавался для конкретной задачи: дать инженеру инструмент, который можно поставить нетехническим пользователям (или использовать самому) для стабильного обхода блокировок, без риска детекции и сломанных руками конфигов.

## Загрузка

- [Android](https://github.com/enkinvsh/dropweb-app/releases) — APK, 6.0+
- [Windows](https://github.com/enkinvsh/dropweb-app/releases) — Portable/Setup, 10+
- [macOS](https://github.com/enkinvsh/dropweb-app/releases) — DMG, 11+ (Intel и Apple Silicon)

Или с сайта: [dropweb.org](https://dropweb.org)

## Фичи

- **Протоколы:** VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard
- **Подписки:** Импорт по URL/QR, автообновление в фоне
- **Маршрутизация:** Локальный трафик напрямую, заблокированный — через прокси (GeoIP/Geosite)
- **UI:** Максимально урезан, только необходимые переключатели

---

## Почему форк и защита от детекции

FlClashX — отличный клиент, но большинство популярных приложений (Happ, v2rayNG, Hiddify, Neko Box) уязвимы к локальному сканированию. Любое приложение на устройстве может найти стандартный SOCKS-порт (7890) без root-прав — это активно используется для [выявления VPN-пользователей](https://habr.com/ru/news/1020902/).

**Как dropweb решает проблему:**

- **Динамические порты** — рандомизация вместо дефолтных 7890/7891
- **SOCKS-аутентификация** — принудительно включена, сканеры не могут проверить тип трафика
- **Только TUN** — выпилен системный прокси (который читается из настроек ОС), весь роутинг через виртуальный интерфейс

---

## Сборка из исходников

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

Требуется Flutter SDK 3.24+. Бинарники mihomo скачиваются автоматически.

---

## Known Issues

- **Android:** Агрессивное энергосбережение (MIUI, ColorOS) может убивать VPN в фоне. Отключите оптимизацию батареи для dropweb
- **macOS:** При первом запуске нужны права администратора для TUN-интерфейса
- **Старые устройства:** На Android с <3 ГБ ОЗУ возможны вылеты при тяжёлых GeoIP-базах

---

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE).

**Ссылки:** [dropweb.org](https://dropweb.org) · [FlClash — оригинальный проект](https://github.com/chen08209/FlClash)

---

<sub>Инструмент создан для обеспечения безопасности личного трафика и доступа к информации. Ответственность за использование несёт пользователь.</sub>
