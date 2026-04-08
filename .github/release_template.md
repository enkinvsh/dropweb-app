<div align="center">

<img src="https://raw.githubusercontent.com/enkinvsh/dropweb-app/main/assets/images/icon.png" alt="dropweb" width="128" />

# dropweb vVERSION

[![Downloads](https://img.shields.io/github/downloads/enkinvsh/dropweb-app/vVERSION/total?style=flat-square&logo=github&color=15803d&label=downloads)](https://github.com/enkinvsh/dropweb-app/releases/tag/vVERSION)

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

> Сборки для **Linux**, **macOS** и **Windows ARM** временно недоступны — вернутся в одном из ближайших релизов.

## ⚠️ Известные проблемы

- Color-bends shader background не отрисовывается на Android из-за Impeller — вместо анимации показывается статический dark gradient
- macOS / Linux / Windows ARM CI временно сломано

## 🔨 Сборка из исходников

```bash
git clone --recurse-submodules https://github.com/enkinvsh/dropweb-app
cd dropweb-app
dart run setup.dart android --arch arm64
```

Подробности — в [README.md](https://github.com/enkinvsh/dropweb-app/blob/main/README.md#%D1%81%D0%B1%D0%BE%D1%80%D0%BA%D0%B0-%D0%B8%D0%B7-%D0%B8%D1%81%D1%85%D0%BE%D0%B4%D0%BD%D0%B8%D0%BA%D0%BE%D0%B2).

## 📜 Лицензия

[GPL-3.0](https://github.com/enkinvsh/dropweb-app/blob/main/LICENSE) — модифицированная версия [FlClashX](https://github.com/pluralplay/FlClashX) на ядре [mihomo](https://github.com/MetaCubeX/mihomo). Все изменения dropweb открыты в этом репозитории.

---

**Полный CHANGELOG:** [CHANGELOG.md](https://github.com/enkinvsh/dropweb-app/blob/main/CHANGELOG.md)
