<img src="assets/images/header.png" alt="dropweb" width="720" />

Форк [FlClashX](https://github.com/pluralplay/FlClashX) на ядре `mihomo`. Кастомный Flutter UI, без рекламы, без телеметрии, лицензия `GPL-3.0`.

[![license](https://img.shields.io/github/license/enkinvsh/dropweb-app?style=for-the-badge&color=15803D&labelColor=0D1117)](LICENSE)
[![release](https://img.shields.io/github/v/release/enkinvsh/dropweb-app?include_prereleases&style=for-the-badge&color=15803D&labelColor=0D1117&label=release)](https://github.com/enkinvsh/dropweb-app/releases)

[english](README_EN.md) · [скачать последнюю сборку →](https://github.com/enkinvsh/dropweb-app/releases)

---

## `$ что делает dropweb`

dropweb — форк [FlClashX](https://github.com/pluralplay/FlClashX). Всё что делает сам FlClashX, продолжает работать. На собственной совести форка — две вещи.

### `lumina` — дизайн-система

Полноценная dark-first дизайн-система, написанная с нуля специально для dropweb. Живой void-фон `#030305` c mesh-градиентом и медленно дрейфующими столбами света на главной, стеклянные поверхности на `white 3%` с blur, биолюминесцентное свечение на активных элементах — зелёный `#15803d`, переходящий в `#22c55e`. Это не тема поверх Material 3 — каждый экран клиента переосмыслен в едином языке.

### `api/secret` — защита localhost

Mihomo-ядро поднимает HTTP API на локалхосте для управления прокси — без защиты любой процесс на устройстве мог бы через него дёргать VPN: переключать сервера, подменять конфиг, снимать трафик. dropweb на каждом запуске генерирует случайный 64-символьный секрет и устанавливает его как `secret` на mihomo external-controller. Без него API отвечает 401 на любой запрос. Секрет живёт только в памяти текущей сессии — никуда не пишется и никуда не передаётся.

## `$ скриншоты`

<table>
<tr>
<td><img src="docs/screenshots/dashboard.png" width="300" alt="главный экран" /></td>
<td><img src="docs/screenshots/proxy.png" width="300" alt="список прокси" /></td>
</tr>
<tr>
<td><sub><code>home</code> — профиль, лимиты, управление</sub></td>
<td><sub><code>proxy</code> — группы, задержки, режимы</sub></td>
</tr>
</table>

## `$ лицензия`

`GPL-3.0` — см. [LICENSE](LICENSE). Все изменения dropweb открыты в этом репозитории. Форк опирается на работу других проектов:

<pre>
dropweb
   └─ <a href="https://github.com/pluralplay/FlClashX">FlClashX</a>
       └─ <a href="https://github.com/chen08209/FlClash">FlClash</a>
           └─ <a href="https://github.com/MetaCubeX/mihomo">mihomo</a>
</pre>
