<div align="center">

<img src="assets/images/icon.png" alt="dropweb" width="160" />

# dropweb

**Современный VPN-клиент для Android, Windows, macOS и Linux**

Форк [FlClashX](https://github.com/pluralplay/FlClashX) на ядре mihomo. Кастомный Flutter UI, без рекламы, без телеметрии, под лицензией GPL-3.0.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**English**](README_EN.md) · [Скачать последнюю сборку →](https://github.com/enkinvsh/dropweb-app/releases/latest)

</div>

---

## Возможности

- 🎨 **LUMINA 2027** — авторская дизайн-система с glass surfaces, mesh gradient и неоновой иконографией
- 🔐 **Серверные заголовки** — `flclashx-*` протокол позволяет провайдеру управлять виджетами, темой и настройками прямо со страницы подписки
- 📡 **Mihomo под капотом** — поддержка VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC и Remnawave-совместимых форматов подписок
- 📱 **HWID-привязка устройства** — приложение всегда знает откуда оно запущено
- 📢 **Виджет анонсов** — провайдер может выводить сообщения прямо на дашборд
- 🖥️ **120 Hz** — поддержка высокочастотных дисплеев на Android
- 📺 **Android TV** — оптимизировано для D-pad и крупных экранов
- 🇷🇺 **Полная русская локализация** — нативный перевод, не машинный
- 🧹 **Без рекламы**, без телеметрии, open source

## Скриншоты

<div align="center">

<img src="docs/screenshots/dashboard.png" width="300" alt="Главный экран" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Список прокси" />

</div>

## Скачать

Все сборки публикуются на странице [Releases →](https://github.com/enkinvsh/dropweb-app/releases/latest)

| Платформа | Файл | Кому |
| --- | --- | --- |
| **Android (arm64)** | `dropweb-android-arm64-v8a.apk` | Рекомендуется для большинства современных устройств |
| **Android (universal)** | `dropweb-android-universal.apk` | Если не уверены в архитектуре |
| **Windows (x64)** | `dropweb-windows-amd64-setup.exe` | Установщик для Windows 10 / 11 |

> Сборки для Linux, macOS и Windows ARM временно недоступны — вернутся в одном из ближайших релизов.

## Серверные заголовки

dropweb поддерживает кастомные HTTP-заголовки со страницы подписки. С их помощью провайдер управляет составом виджетов на главной, оформлением и поведением клиента — без необходимости обновлять сам APK. Особенно удобно для подписочных панелей на базе [Remnawave](https://remna.st) и подобных.

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

```http
flclashx-widgets: announce,metainfo,outboundModeV2,networkDetection
```

</details>

<details>
<summary><strong>flclashx-view</strong> — внешний вид страницы прокси</summary>

| Параметр | Возможные значения |
| :------: | ------------------ |
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
<summary><strong>flclashx-hex</strong> — тема и цвет акцента</summary>

```http
flclashx-hex: 15803d
flclashx-hex: 15803d:vibrant
flclashx-hex: 15803d:vibrant:pureblack
```

Формат: `<hex>[:<вариант>][:<фон>]`. Варианты — `tonalSpot`, `vibrant`, `expressive`, `content`, `fidelity`. Фон — `pureblack` для AMOLED.

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

```http
flclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate
```

</details>

<details>
<summary><strong>Остальные заголовки</strong></summary>

- `flclashx-custom: add|update` — когда применять стили (только при добавлении подписки или каждый раз при обновлении)
- `flclashx-denywidgets: true` — запретить пользователю редактировать Dashboard
- `flclashx-servicename: Название` — имя сервиса в виджете ServiceInfo
- `flclashx-servicelogo: https://...` — логотип сервиса (svg или png)
- `flclashx-serverinfo: ProxyGroup` — группа для виджета смены сервера
- `flclashx-background: https://...` — фоновое изображение главного экрана
- `flclashx-globalmode: false` — скрыть переключатель режима прокси

</details>

## Сборка из исходников

### Требования

- Flutter SDK ≥ 3.5.0
- Android NDK 28
- Go 1.21+ (для ядра mihomo)

dropweb использует FlClashX-конвенцию `setup.dart` вместо `flutter build` — этот скрипт собирает Go core, линкует нативную библиотеку и упаковывает Flutter-бандл.

### Android (arm64)

```bash
dart run setup.dart android --arch arm64
```

Готовый APK появится в `dist/dropweb-android-arm64-v8a.apk`.

### Linux

Перед сборкой установите системные зависимости:

```bash
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev
```

Затем:

```bash
dart run setup.dart linux --arch amd64
```

### Windows / macOS

Аналогично — см. `setup.dart` для полного списка поддерживаемых платформ и архитектур.

## Лицензия

GPL-3.0 — см. [LICENSE](LICENSE).

dropweb — модифицированная версия FlClashX. Исходные работы:

- [chen08209/FlClash](https://github.com/chen08209/FlClash) — оригинальный Flutter-клиент
- [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX) — fork с расширениями для подписочных провайдеров
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) — proxy core, на котором всё держится

Все изменения dropweb открыты и доступны в этом репозитории под той же лицензией GPL-3.0.
