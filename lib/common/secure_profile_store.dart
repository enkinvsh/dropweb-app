import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for subscription URLs, keyed by profile id.
///
/// Subscription URLs almost always carry an auth token in the path or query
/// (`https://example.com/sub/<token>`, `https://api/?uuid=...`). Keeping them
/// in SharedPreferences means another app with root on the device — or any
/// tooling that can read `/data/data/<pkg>/shared_prefs/*.xml` during a
/// support session or debug dump — can harvest live VPN credentials.
///
/// Android backs `flutter_secure_storage` with EncryptedSharedPreferences
/// (AES-256/Keystore-wrapped key). iOS uses the Keychain. Desktop platforms
/// use the OS credential store.
///
/// Non-sensitive Profile fields (labels, flags, update schedule, selected
/// proxies map, override rules) continue to live in the main Config blob in
/// SharedPreferences — moving them here would cost IPC round-trips on every
/// scroll of the Proxies page.
class SecureProfileUrlStore {
  SecureProfileUrlStore._();

  static final SecureProfileUrlStore instance = SecureProfileUrlStore._();

  static const _urlKeyPrefix = 'profile_url:';
  static const _fallbackKeyPrefix = 'profile_fallback_url:';
  // Flips to 1 after the first successful migration run so we don't re-scan
  // SharedPreferences on every launch.
  static const _migrationKey = 'profile_url_migrated_v1';

  // AndroidOptions intentionally left default. In flutter_secure_storage
  // v10 the `encryptedSharedPreferences` flag is a no-op (Jetpack Security
  // was deprecated by Google); the plugin auto-migrates to its own AES-GCM
  // ciphers on first access. KeychainAccessibility.first_unlock on iOS
  // means the Keychain item is readable after the user unlocks the device
  // once per boot, then stays readable — appropriate for a VPN client that
  // may need to reconnect in the background.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  Future<String?> getUrl(String profileId) async {
    try {
      return await _storage.read(key: '$_urlKeyPrefix$profileId');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureProfileStore] getUrl failed: $e');
      }
      return null;
    }
  }

  Future<String?> getFallbackUrl(String profileId) async {
    try {
      return await _storage.read(key: '$_fallbackKeyPrefix$profileId');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureProfileStore] getFallbackUrl failed: $e');
      }
      return null;
    }
  }

  Future<void> setUrl(String profileId, String? url) async {
    try {
      final key = '$_urlKeyPrefix$profileId';
      if (url == null || url.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: url);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureProfileStore] setUrl failed: $e');
      }
    }
  }

  Future<void> setFallbackUrl(String profileId, String? url) async {
    try {
      final key = '$_fallbackKeyPrefix$profileId';
      if (url == null || url.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: url);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureProfileStore] setFallbackUrl failed: $e');
      }
    }
  }

  Future<void> removeProfile(String profileId) async {
    await setUrl(profileId, null);
    await setFallbackUrl(profileId, null);
  }

  Future<bool> isMigrated() async {
    try {
      return await _storage.read(key: _migrationKey) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> markMigrated() async {
    try {
      await _storage.write(key: _migrationKey, value: '1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureProfileStore] markMigrated failed: $e');
      }
    }
  }
}

final secureProfileUrlStore = SecureProfileUrlStore.instance;
