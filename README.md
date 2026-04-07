<div align="center">

# dropweb

VPN-клиент для Android, macOS, Windows, Linux

Форк [FlClashX](https://github.com/pluralplay/FlClashX) на основе [FlClash](https://github.com/chen08209/FlClash) и ядра mihomo.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&logo=github)](https://github.com/enkinvsh/dropweb-app/releases/)

[**English**](README_EN.md)

</div>

## Возможности

- 🎨 LUMINA 2027 — авторская дизайн-система с glass surfaces и mesh gradient
- 🔐 Поддержка серверных заголовков (flclashx-* протокол)
- 📱 HWID привязка устройства
- 📢 Виджет анонсов от провайдера
- 🖥️ Поддержка 120Гц дисплеев
- 🇷🇺 Полная русская локализация
- 📺 Оптимизация для Android TV
- 🧹 Без рекламы, open source

## Скачать

- [APK для Android](https://dropweb.org/app)
- Google Play — скоро

## Серверные заголовки

Приложение поддерживает кастомные заголовки со страницы подписки для управления виджетами, внешним видом и настройками.

<details>
<summary><strong>flclashx-widgets</strong> — порядок виджетов на главной</summary>

| Значение | Виджет |
| :------: | ------ |
| `announce` | Анонсы |
| `networkSpeed` | Скорость сети |
| `outboundModeV2` | Режим прокси (новый вид) |
| `outboundMode` | Режим прокси (старый вид) |
| `trafficUsage` | Использование трафика |
| `networkDetection` | IP и локация |
| `tunButton` | Кнопка TUN (Desktop) |
| `vpnButton` | Кнопка VPN (Android) |
| `systemProxyButton` | Системный прокси (Desktop) |
| `intranetIp` | Локальный IP |
| `memoryInfo` | Память |
| `metainfo` | Информация о подписке |
| `changeServerButton` | Смена сервера |
| `serviceInfo` | Информация о сервисе |

```bash
flclashx-widgets: announce,metainfo,outboundModeV2,networkDetection
```
</details>

<details>
<summary><strong>flclashx-view</strong> — вид страницы прокси</summary>

| Параметр | Возможные значения |
| :------: | ------------------ |
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
<summary><strong>flclashx-hex</strong> — тема и цвет акцента</summary>

```bash
flclashx-hex: 15803d
flclashx-hex: 15803d:vibrant
flclashx-hex: 15803d:vibrant:pureblack
```
</details>

<details>
<summary><strong>flclashx-settings</strong> — настройки через подписку</summary>

| Параметр | Описание |
| :------: | -------- |
| `minimize` | Сворачивать вместо закрытия |
| `autorun` | Автозапуск с системой |
| `shadowstart` | Запуск свёрнутым в трей |
| `autostart` | Автостарт прокси |
| `autoupdate` | Проверять обновления |

```bash
flclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate
```
</details>

<details>
<summary><strong>Остальные заголовки</strong></summary>

- `flclashx-custom: add|update` — когда применять стили (при добавлении или каждом обновлении)
- `flclashx-denywidgets: true` — запретить редактировать Dashboard
- `flclashx-servicename: Название` — имя сервиса в виджете ServiceInfo
- `flclashx-servicelogo: https://...` — логотип сервиса (svg/png)
- `flclashx-serverinfo: ProxyGroup` — группа для виджета смены сервера
- `flclashx-background: https://...` — фоновое изображение
- `flclashx-globalmode: false` — скрыть переключатель режима прокси
</details>

## Сборка

### Требования

- Flutter SDK >=3.5.0
- Android NDK 28
- Go (для ядра)

### Android

```bash
dart run setup.dart android --arch arm64
```

Собранный APK: `dist/dropweb-android-arm64-v8a.apk`

### Linux

Перед сборкой установите зависимости:

```bash
sudo apt-get install libayatana-appindicator3-dev
sudo apt-get install libkeybinder-3.0-dev
```

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE)

Это модифицированная версия FlClashX. Оригинальная работа: [chen08209/FlClash](https://github.com/chen08209/FlClash) и [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX).
