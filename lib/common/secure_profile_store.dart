import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted store for subscription URLs (tokens embedded) — SharedPreferences
/// is readable via ADB backup and by rooted companions. Only URLs live here;
/// the rest of Profile stays in the plaintext Config blob for fast access.
class SecureProfileUrlStore {
  SecureProfileUrlStore._();

  static final SecureProfileUrlStore instance = SecureProfileUrlStore._();

  static const _urlKeyPrefix = 'profile_url:';
  static const _fallbackKeyPrefix = 'profile_fallback_url:';
  static const _migrationKey = 'profile_url_migrated_v1';

  // first_unlock — readable once the device is unlocked, stays readable after
  // (VPN may need to reconnect in background).
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
