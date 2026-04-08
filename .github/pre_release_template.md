<div align="center">

<img src="https://raw.githubusercontent.com/enkinvsh/dropweb-app/main/assets/images/icon.png" alt="dropweb" width="128" />

# dropweb vVERSION

⚠️ **Pre-release сборка** — для тестирования. Возможны баги, нестабильное поведение, регрессии.

[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/vVERSION/total?style=flat-square&logo=github&color=eab308&label=downloads)](https://github.com/enkinvsh/dropweb-app/releases/tag/vVERSION)

</div>

---

## 📥 Скачать

### Android

| Файл | Архитектура | Кому |
| --- | --- | --- |
| [`dropweb-android-arm64-v8a.apk`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-android-arm64-v8a.apk) | `arm64-v8a` | Большинство современных устройств |
| [`dropweb-android-universal.apk`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-android-universal.apk) | все | Если не уверены в архитектуре |
| [`dropweb-android-armeabi-v7a.apk`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-android-armeabi-v7a.apk) | `armv7` | Старые устройства (Android 7+) |
| [`dropweb-android-x86_64.apk`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-android-x86_64.apk) | `x86_64` | Эмуляторы, Chromebook |

### Windows

| Файл | Тип |
| --- | --- |
| [`dropweb-windows-amd64-setup.exe`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-windows-amd64-setup.exe) | Установщик x64 (Windows 10/11) |
| [`dropweb-windows-amd64.zip`](https://github.com/enkinvsh/dropweb-app/releases/download/vVERSION/dropweb-windows-amd64.zip) | Portable x64 (без установки) |

> Сборки для **Linux**, **macOS** и **Windows ARM** временно недоступны.

## ⚠️ Известные проблемы

- Это **pre-release**: возможны regressions, не разворачивайте в продакшн
- Color-bends shader background не отрисовывается на Android из-за Impeller — статический dark gradient вместо анимации
- macOS / Linux / Windows ARM CI временно сломано

## 🐛 Обнаружили баг?

Откройте [issue в репозитории](https://github.com/enkinvsh/dropweb-app/issues/new?template=bug_report.yml) — укажите шаги воспроизведения и версию `vVERSION`.

## 🔨 Сборка из исходников

```bash
git clone --recurse-submodules https://github.com/enkinvsh/dropweb-app
cd dropweb-app
dart run setup.dart android --arch arm64
```

## 📜 Лицензия

[GPL-3.0](https://github.com/enkinvsh/dropweb-app/blob/main/LICENSE) — модифицированная версия [FlClashX](https://github.com/pluralplay/FlClashX) на ядре [mihomo](https://github.com/MetaCubeX/mihomo).

---

**Full changelog:** [CHANGELOG.md](https://github.com/enkinvsh/dropweb-app/blob/main/CHANGELOG.md)
