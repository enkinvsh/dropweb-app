import 'dart:async';

import 'package:flutter/services.dart';

/// In-memory circular buffer for ParazitX diagnostic logs.
///
/// The buffer holds the last [_maxLines] lines of relay stdout + status
/// events so the user can ship them to the callfactory for debugging
/// via the dev menu ("📤 Отправить логи").
///
/// Nothing sensitive should ever land here: lines are routed through
/// [_sanitize] which drops/masks VK cookies, auth tokens, SOCKS creds,
/// and join links.
class LogBuffer {
  LogBuffer._();

  static final LogBuffer _instance = LogBuffer._();
  static LogBuffer get instance => _instance;

  static const _maxLines = 500;

  final _buffer = <String>[];
  StreamSubscription<dynamic>? _nativeSub;

  /// Start listening to the native EventChannel that relays stdout lines
  /// from `:parazitx` process through MainActivity. Safe to call multiple
  /// times — idempotent.
  void attachNativeChannel() {
    if (_nativeSub != null) return;
    const channel = EventChannel('app.dropweb/parazitx/logs');
    _nativeSub = channel.receiveBroadcastStream().listen(
      (dynamic line) {
        if (line is String) add('relay: $line');
      },
      onError: (Object err) {
        add('relay log channel error: $err');
      },
    );
  }

  void add(String line) {
    final sanitized = _sanitize(line);
    if (sanitized == null) return;
    final stamped = '[${DateTime.now().toUtc().toIso8601String()}] $sanitized';
    _buffer.add(stamped);
    if (_buffer.length > _maxLines) {
      _buffer.removeAt(0);
    }
  }

  List<String> getAll() => List.unmodifiable(_buffer);

  void clear() => _buffer.clear();

  /// Drop lines that contain sensitive data entirely, or mask sensitive
  /// fragments. Returns null to skip the line.
  static final _dropPatterns = <RegExp>[
    RegExp(r'remixdsid|remixnsid|remixsid|vk_access_token',
        caseSensitive: false),
    RegExp(r'Cookie:\s*', caseSensitive: false),
    RegExp(r'Authorization:\s*', caseSensitive: false),
  ];

  static final _joinLinkMask =
      RegExp(r'https://vk\.com/call/join/[A-Za-z0-9_\-]+');
  static final _socksCredMask = RegExp(r'socks5://[^:]+:[^@\s]+@');
  static final _longTokenMask = RegExp(r'[A-Za-z0-9_\-]{40,}');

  static String? _sanitize(String line) {
    for (final p in _dropPatterns) {
      if (p.hasMatch(line)) return null;
    }
    var s = line;
    s = s.replaceAll(_joinLinkMask, 'https://vk.com/call/join/<redacted>');
    s = s.replaceAll(_socksCredMask, 'socks5://<redacted>@');
    s = s.replaceAllMapped(_longTokenMask, (m) {
      final t = m.group(0)!;
      return '${t.substring(0, 6)}<redacted:${t.length}>';
    });
    return s;
  }
}
