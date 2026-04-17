import 'dart:math';
import 'package:dropweb/models/core.dart';

/// Generates cryptographically random proxy credentials.
/// Used to protect SOCKS/HTTP port from detection by other apps.
class ProxyCredentialsGenerator {
  static final _random = Random.secure();
  static const _chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Port range: 10000-59999 (avoid well-known ports and ephemeral range)
  static const _minPort = 10000;
  static const _maxPort = 59999;

  /// Generate a random string of given length
  static String _randomString(int length) {
    return List.generate(length, (_) => _chars[_random.nextInt(_chars.length)])
        .join();
  }

  /// Generate a random port in the valid range
  static int generatePort() {
    return _minPort + _random.nextInt(_maxPort - _minPort);
  }

  /// Generate new random credentials for this VPN session.
  /// If [persistedPort] is provided, uses that port instead of generating new.
  /// Username/password are always regenerated per session for security.
  static ProxyCredentials generate({int? persistedPort}) {
    return ProxyCredentials(
      port: persistedPort ?? generatePort(),
      username: 'u${_randomString(8)}',
      password: _randomString(24),
    );
  }

  /// Format credentials for mihomo authentication config
  /// Returns: ["username:password"]
  static List<String> toMihomoAuth(ProxyCredentials creds) {
    return ['${creds.username}:${creds.password}'];
  }
}
