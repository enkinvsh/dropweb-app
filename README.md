<div align="center">

<img src="assets/images/icon.png" alt="dropweb" width="160" />

# dropweb

**Современный VPN-клиент для Android, Windows, macOS и Linux**

Форк [FlClashX](https://github.com/pluralplay/FlClashX) на ядре mihomo. Кастомный Flutter UI, без рекламы, без телеметрии, под лицензией GPL-3.0.

[![License](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=flat-square&color=15803d)](LICENSE)
[![Release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=flat-square&color=15803d&label=release)](https://github.com/enkinvsh/dropweb-app/releases)
[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/total?style=flat-square&color=15803d&logo=github&logoColor=white)](https://github.com/enkinvsh/dropweb-app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-15803d?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)

[**English**](README_EN.md) · [Скачать последнюю сборку →](https://github.com/enkinvsh/dropweb-app/releases)

</div>

---

## Что добавляет dropweb

dropweb — форк [FlClashX](https://github.com/pluralplay/FlClashX). Всё что делает сам FlClashX, продолжает работать. На собственной совести форка — две вещи.

### LUMINA — дизайн-система

Полноценная dark-first дизайн-система, написанная с нуля специально для dropweb. Живой void-фон `#030305` c mesh-градиентом и медленно дрейфующими столбами света на главной, стеклянные поверхности на `white 3%` с blur, биолюминесцентное свечение на активных элементах — зелёный `#15803d`, переходящий в `#22c55e`. Это не тема поверх Material 3 — каждый экран клиента переосмыслен в едином языке.

Токены и хелперы собраны в [`lib/common/lumina.dart`](lib/common/lumina.dart), фон — в [`lib/widgets/mesh_background.dart`](lib/widgets/mesh_background.dart) и [`lib/widgets/light_pillar.dart`](lib/widgets/light_pillar.dart). Полный спек и маппинг CSS → Flutter лежат в [`docs/plans/2026-04-06-lumina-design-system.md`](docs/plans/2026-04-06-lumina-design-system.md).

### HWID — привязка подписки к устройству

Клиент считывает стабильный hardware ID устройства и передаёт его провайдеру при обращении к подписке. Если ключ утечёт — им нельзя будет воспользоваться с другого телефона: сервер провайдера увидит чужой идентификатор и откажет. Защита от перепродажи ключей, шаринга аккаунтов и replay-атак с утёкшими подписками.

Поведение опциональное — включается на стороне провайдера, клиент передаёт идентификатор только когда об этом просит панель подписки. Локально никаких данных о пользователе не хранится и никуда больше не уходит.

## Скриншоты

<div align="center">

<img src="docs/screenshots/dashboard.png" width="300" alt="Главный экран" />&nbsp;<img src="docs/screenshots/proxy.png" width="300" alt="Список прокси" />

</div>

## Скачать

Все сборки публикуются на странице [Releases →](https://github.com/enkinvsh/dropweb-app/releases)

| Платформа | Файл | Кому |
| --- | --- | --- |
| **Android (arm64)** | `dropweb-android-arm64-v8a.apk` | Рекомендуется для большинства современных устройств |
| **Android (universal)** | `dropweb-android-universal.apk` | Если не уверены в архитектуре |
| **Windows (x64)** | `dropweb-windows-amd64-setup.exe` | Установщик для Windows 10 / 11 |

> Сборки для Linux, macOS и Windows ARM временно недоступны — вернутся в одном из ближайших релизов.

## Что унаследовано от FlClashX и mihomo

От [mihomo](https://github.com/MetaCubeX/mihomo) — протоколы VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC и поддержка Remnawave-совместимых подписок. От [FlClash](https://github.com/chen08209/FlClash) — Android TV, 120 Hz и база русской локализации. От [FlClashX](https://github.com/pluralplay/FlClashX) — протокол серверных заголовков `flclashx-*` (справочник — ниже) и виджет анонсов. Всё это работает в dropweb как есть; форк ничего из этого не ломает.

## Серверные заголовки (протокол FlClashX)

Это унаследованный из FlClashX протокол. dropweb его не меняет, но оставляет рабочим для совместимости с Remnawave-подобными подписочными панелями — провайдер может управлять составом виджетов на главной, оформлением и поведением клиента прямо со страницы подписки, без необходимости обновлять сам APK.

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
