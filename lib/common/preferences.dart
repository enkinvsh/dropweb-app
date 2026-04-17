import 'dart:async';
import 'dart:convert';

import 'package:dropweb/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';
import 'secure_profile_store.dart';

class Preferences {
  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, __) => sharedPreferencesCompleter.complete(null));
  }
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Future<ClashConfig?> getClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final clashConfigString = preferences?.getString(clashConfigKey);
    if (clashConfigString == null) return null;
    final clashConfigMap = json.decode(clashConfigString);
    return ClashConfig.fromJson(clashConfigMap);
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return null;
    final configString = preferences.getString(configKey);
    if (configString == null) return null;
    final configMap = json.decode(configString);
    final config = Config.compatibleFromJson(configMap);

    // SECURITY: one-time migration of subscription URLs out of
    // SharedPreferences into encrypted storage. On the first launch after
    // the upgrade, URLs are still present in the JSON blob — harvest them,
    // write them to secure storage, and persist the stripped config back so
    // the plaintext leaks only once. After markMigrated() this branch never
    // runs again.
    final alreadyMigrated = await secureProfileUrlStore.isMigrated();
    if (!alreadyMigrated) {
      var anyUrlPresent = false;
      for (final profile in config.profiles) {
        if (profile.url.isNotEmpty) {
          await secureProfileUrlStore.setUrl(profile.id, profile.url);
          anyUrlPresent = true;
        }
        final fb = profile.fallbackUrl;
        if (fb != null && fb.isNotEmpty) {
          await secureProfileUrlStore.setFallbackUrl(profile.id, fb);
          anyUrlPresent = true;
        }
      }
      await secureProfileUrlStore.markMigrated();
      if (anyUrlPresent) {
        // Overwrite the plaintext blob in-place with a stripped copy.
        await _writeConfigStripped(config, preferences);
      }
      return _rehydrateWithSecureUrls(config);
    }

    return _rehydrateWithSecureUrls(config);
  }

  /// After [_writeConfigStripped] cleared the in-memory [Profile.url] /
  /// [Profile.fallbackUrl] fields on disk, this fills them back from the
  /// encrypted store so the rest of the app sees a fully-populated Config.
  Future<Config> _rehydrateWithSecureUrls(Config config) async {
    if (config.profiles.isEmpty) return config;
    final rehydrated = <Profile>[];
    for (final profile in config.profiles) {
      final secureUrl = await secureProfileUrlStore.getUrl(profile.id);
      final secureFallback =
          await secureProfileUrlStore.getFallbackUrl(profile.id);
      rehydrated.add(
        profile.copyWith(
          url: secureUrl ?? profile.url,
          fallbackUrl: secureFallback ?? profile.fallbackUrl,
        ),
      );
    }
    return config.copyWith(profiles: rehydrated);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return false;

    // Sync the encrypted store with the current profile list so URLs we
    // haven't seen before land there (new subscription added at runtime),
    // and URLs for deleted profiles are scrubbed.
    for (final profile in config.profiles) {
      await secureProfileUrlStore.setUrl(profile.id, profile.url);
      await secureProfileUrlStore.setFallbackUrl(
        profile.id,
        profile.fallbackUrl,
      );
    }

    return _writeConfigStripped(config, preferences);
  }

  /// Writes [config] to SharedPreferences after replacing every profile's
  /// `url` / `fallbackUrl` with empty placeholders. Callers MUST keep the
  /// real URLs in [secureProfileUrlStore] in sync before invoking this —
  /// otherwise the data is gone.
  Future<bool> _writeConfigStripped(
    Config config,
    SharedPreferences preferences,
  ) async {
    final strippedProfiles = config.profiles
        .map(
          (p) => p.copyWith(
            url: '',
            fallbackUrl: null,
          ),
        )
        .toList();
    final strippedConfig = config.copyWith(profiles: strippedProfiles);
    return preferences.setString(
      configKey,
      json.encode(strippedConfig),
    );
  }

  Future<void> clearClashConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    preferences?.remove(clashConfigKey);
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    sharedPreferencesIns?.clear();
  }

  /// Get persisted SOCKS port (null if never generated)
  Future<int?> getSocksPort() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt(socksPortKey);
  }

  /// Save SOCKS port for persistence across restarts
  Future<bool> saveSocksPort(int port) async {
    final preferences = await sharedPreferencesCompleter.future;
    return await preferences?.setInt(socksPortKey, port) ?? false;
  }
}

final preferences = Preferences();
