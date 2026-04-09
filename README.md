<img src="assets/images/header.png" alt="dropweb" width="720" />

# dropweb

**Современный VPN-клиент для Android, Windows, macOS и Linux**

Форк [FlClashX](https://github.com/pluralplay/FlClashX) на ядре mihomo. Кастомный Flutter UI, без рекламы, без телеметрии, под лицензией GPL-3.0.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**English**](README_EN.md) · [Скачать последнюю сборку →](https://github.com/enkinvsh/dropweb-app/releases)

---

## Что добавляет dropweb

dropweb — форк [FlClashX](https://github.com/pluralplay/FlClashX). Всё что делает сам FlClashX, продолжает работать. На собственной совести форка — две вещи.

### LUMINA — дизайн-система

Полноценная dark-first дизайн-система, написанная с нуля специально для dropweb. Живой void-фон `#030305` c mesh-градиентом и медленно дрейфующими столбами света на главной, стеклянные поверхности на `white 3%` с blur, биолюминесцентное свечение на активных элементах — зелёный `#15803d`, переходящий в `#22c55e`. Это не тема поверх Material 3 — каждый экран клиента переосмыслен в едином языке.

### Защита localhost API

Mihomo-ядро поднимает HTTP API на локалхосте для управления прокси — без защиты любой процесс на устройстве мог бы через него дёргать VPN: переключать сервера, подменять конфиг, снимать трафик. dropweb на каждом запуске генерирует случайный 64-символьный секрет и устанавливает его как `secret` на mihomo external-controller. Без него API отвечает 401 на любой запрос. Секрет живёт только в памяти текущей сессии — никуда не пишется и никуда не передаётся.

## Скриншоты

<img src="docs/screenshots/dashboard.png" width="300" alt="Главный экран" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Список прокси" />

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE). Все изменения dropweb открыты в этом репозитории.

Форк опирается на работу других проектов: [FlClashX](https://github.com/pluralplay/FlClashX) → [FlClash](https://github.com/chen08209/FlClash) → [mihomo](https://github.com/MetaCubeX/mihomo).
