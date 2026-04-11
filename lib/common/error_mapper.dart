import 'package:intl/intl.dart';

/// Maps raw mihomo core error strings to human-readable messages.
///
/// The core sends technical error logs like "dial tcp 1.2.3.4:443: i/o timeout"
/// which mean nothing to regular users. This mapper translates them to clear
/// messages with actionable suggestions.
class ErrorMapper {
  ErrorMapper._();

  static final _patterns = <_ErrorPattern>[
    // Network unreachable / no internet
    _ErrorPattern(
      RegExp(r'network is unreachable|no route to host', caseSensitive: false),
      ru: 'Нет подключения к интернету. Проверьте Wi-Fi или мобильную сеть.',
      en: 'No internet connection. Check your Wi-Fi or mobile network.',
    ),
    // DNS failure
    _ErrorPattern(
      RegExp(r'all DNS request failed|no such host|dns.*fail',
          caseSensitive: false),
      ru: 'Не удаётся найти сервер. Проверьте подключение к интернету.',
      en: 'Cannot find server. Check your internet connection.',
    ),
    // Connection timeout
    _ErrorPattern(
      RegExp(r'i/o timeout|context deadline exceeded|connection timed out',
          caseSensitive: false),
      ru: 'Сервер не отвечает. Попробуйте другой сервер или подождите.',
      en: 'Server is not responding. Try a different server or wait.',
    ),
    // Connection refused
    _ErrorPattern(
      RegExp(r'connection refused', caseSensitive: false),
      ru: 'Сервер отклонил подключение. Попробуйте другой сервер.',
      en: 'Server refused the connection. Try a different server.',
    ),
    // Connection reset
    _ErrorPattern(
      RegExp(r'connection reset by peer|broken pipe', caseSensitive: false),
      ru: 'Соединение прервано. Попробуйте подключиться ещё раз.',
      en: 'Connection was interrupted. Try reconnecting.',
    ),
    // EOF (generic connection drop)
    _ErrorPattern(
      RegExp(r'EOF|unexpected EOF', caseSensitive: false),
      ru: 'Соединение с сервером потеряно. Попробуйте ещё раз.',
      en: 'Lost connection to server. Try again.',
    ),
    // TLS / Reality handshake errors
    _ErrorPattern(
      RegExp(r'tls.*handshake|reality.*verif|certificate',
          caseSensitive: false),
      ru: 'Ошибка безопасного соединения. Обновите подписку или попробуйте другой сервер.',
      en: 'Secure connection failed. Update your subscription or try a different server.',
    ),
    // Proxy not found
    _ErrorPattern(
      RegExp(r'proxy.*not found|proxy adapter not found', caseSensitive: false),
      ru: 'Сервер не найден в конфигурации. Обновите подписку.',
      en: 'Server not found in configuration. Update your subscription.',
    ),
    // Address in use (port conflict)
    _ErrorPattern(
      RegExp(r'address already in use', caseSensitive: false),
      ru: 'Порт уже занят другим приложением. Перезапустите VPN.',
      en: 'Port is already in use by another app. Restart VPN.',
    ),
    // Too many open files
    _ErrorPattern(
      RegExp(r'too many open files', caseSensitive: false),
      ru: 'Слишком много подключений. Перезапустите VPN.',
      en: 'Too many connections. Restart VPN.',
    ),
    // Authentication errors
    _ErrorPattern(
      RegExp(r'auth.*fail|authentication.*fail|unauthorized',
          caseSensitive: false),
      ru: 'Ошибка авторизации. Обновите подписку.',
      en: 'Authentication failed. Update your subscription.',
    ),
  ];

  /// Translates a raw error string to a human-readable message.
  /// Returns null if the error doesn't match any known pattern (shown as-is).
  static String? mapError(String rawError) {
    for (final pattern in _patterns) {
      if (pattern.regex.hasMatch(rawError)) {
        return _isRussian ? pattern.ru : pattern.en;
      }
    }
    return null;
  }

  /// VPN service failed to start.
  static String get vpnStartFailed => _isRussian
      ? 'Не удалось запустить VPN. Возможно, другое VPN-приложение уже активно.'
      : 'Failed to start VPN. Another VPN app may be active.';

  /// VPN permission denied by user.
  static String get vpnPermissionDenied => _isRussian
      ? 'Нет разрешения на VPN. Разрешите подключение при следующем запросе.'
      : 'VPN permission denied. Allow the connection when prompted.';

  static bool get _isRussian {
    final locale = Intl.defaultLocale ?? 'en';
    return locale.startsWith('ru');
  }
}

class _ErrorPattern {
  const _ErrorPattern(this.regex, {required this.ru, required this.en});
  final RegExp regex;
  final String ru;
  final String en;
}
