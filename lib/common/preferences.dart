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

  /// Loads Config (without URLs — those are in [SecureProfileUrlStore],
  /// fetched lazily via [getProfileUrl] to keep startup free of Keystore IPC).
  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return null;
    final configString = preferences.getString(configKey);
    if (configString == null) return null;
    final configMap = json.decode(configString);
    return Config.compatibleFromJson(configMap);
  }

  /// Profile URL from encrypted store; falls back to in-memory copy if
  /// migration hasn't run yet. Tolerate keystore being slow right after boot.
  Future<String?> getProfileUrl(Profile profile) async {
    final fromStore = await secureProfileUrlStore.getUrl(profile.id);
    if (fromStore != null && fromStore.isNotEmpty) return fromStore;
    return profile.url.isEmpty ? null : profile.url;
  }

  Future<String?> getProfileFallbackUrl(Profile profile) async {
    final fromStore = await secureProfileUrlStore.getFallbackUrl(profile.id);
    if (fromStore != null && fromStore.isNotEmpty) return fromStore;
    return profile.fallbackUrl;
  }

  /// One-time move of plaintext URLs into encrypted store. Idempotent.
  /// MUST run post-frame so a slow keystore can't keep the splash on screen.
  Future<void> migrateProfileUrlsIfNeeded() async {
    if (await secureProfileUrlStore.isMigrated()) return;

    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return;
    final configString = preferences.getString(configKey);
    if (configString == null) {
      await secureProfileUrlStore.markMigrated();
      return;
    }

    final config = Config.compatibleFromJson(json.decode(configString));
    var wrotePlaintext = false;
    for (final profile in config.profiles) {
      if (profile.url.isNotEmpty) {
        await secureProfileUrlStore.setUrl(profile.id, profile.url);
        wrotePlaintext = true;
      }
      final fb = profile.fallbackUrl;
      if (fb != null && fb.isNotEmpty) {
        await secureProfileUrlStore.setFallbackUrl(profile.id, fb);
        wrotePlaintext = true;
      }
    }
    await secureProfileUrlStore.markMigrated();
    if (wrotePlaintext) {
      await _writeConfigStripped(config, preferences);
    }
  }

  /// Persist Config — URLs go to the encrypted store, JSON blob is stripped.
  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return false;

    for (final profile in config.profiles) {
      if (profile.url.isNotEmpty) {
        await secureProfileUrlStore.setUrl(profile.id, profile.url);
      }
      if (profile.fallbackUrl != null && profile.fallbackUrl!.isNotEmpty) {
        await secureProfileUrlStore.setFallbackUrl(
          profile.id,
          profile.fallbackUrl,
        );
      }
    }

    return _writeConfigStripped(config, preferences);
  }

  /// Writes Config with empty url/fallbackUrl. Callers MUST first sync the
  /// real values to [secureProfileUrlStore] or the data is lost.
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
