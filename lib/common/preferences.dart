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

  /// Load the app's Config from SharedPreferences.
  ///
  /// NOTE: profile URLs are NOT rehydrated here. They live in the
  /// encrypted [SecureProfileUrlStore] and are read on demand — by
  /// [Profile.update] when refreshing a subscription, by the edit-profile
  /// form when the user opens it, etc. That design keeps the startup path
  /// free of any Android Keystore IPC, which after a cold boot on some
  /// devices can block for seconds (or indefinitely until the user unlocks)
  /// and leaves the app stuck on the native splash.
  ///
  /// On the first launch after the Phase-9 upgrade the JSON blob still
  /// carries plaintext URLs; [_migrateIfNeeded] moves them to the secure
  /// store and scrubs the blob. That happens AFTER the splash is gone and
  /// the UI has rendered (see [AppController.init]).
  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return null;
    final configString = preferences.getString(configKey);
    if (configString == null) return null;
    final configMap = json.decode(configString);
    return Config.compatibleFromJson(configMap);
  }

  /// Read a profile's URL from encrypted storage.
  ///
  /// Falls back to the URL embedded in the config blob for pre-migration
  /// state (i.e. someone upgrading from <0.4.7 whose migration hasn't run
  /// yet, or whose migration deferred). Callers MUST be tolerant of the
  /// keystore being unavailable right after boot.
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

  /// Idempotent URL migration — moves any plaintext URLs from the config
  /// blob into the secure store, then rewrites the blob with stripped
  /// copies. Safe to call repeatedly; does nothing if already migrated.
  ///
  /// Must be invoked AFTER the UI is running (e.g. from a post-frame
  /// callback in AppController.init) so a slow keystore can't keep the
  /// splash on screen. See getConfig() docstring for the rationale.
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

  /// Persist a Config. Any non-empty URLs carried on [Profile] (added
  /// through the UI, or freshly imported) are copied into the encrypted
  /// store here; the on-disk JSON blob gets the URLs stripped so the
  /// SharedPreferences file never contains plaintext subscription tokens.
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
