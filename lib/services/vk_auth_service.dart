import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show CookieManager, InAppWebViewController, WebUri;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VkAuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
  );

  static const _cookieKey = 'vk_session_cookies';

  /// Extract cookies after VK login
  /// Captures ALL cookies from vk.com domain — VK's web_token endpoint
  /// requires more than just remixsid (httoken, remixnsid, p, remixgp, etc.)
  static Future<String?> extractCookies() async {
    final cookieManager = CookieManager.instance();

    // VK sets remixsid and related auth cookies across multiple origins.
    // We must query all of them and deduplicate by name.
    const origins = [
      'https://vk.com',
      'https://login.vk.com',
      'https://m.vk.com',
      'https://api.vk.com',
    ];

    final seen = <String>{};
    final parts = <String>[];

    for (final origin in origins) {
      final cookies = await cookieManager.getCookies(url: WebUri(origin));
      for (final c in cookies) {
        if (seen.add(c.name)) {
          parts.add('${c.name}=${c.value}');
        }
      }
    }

    final cookieStr = parts.join('; ');

    if (cookieStr.contains('remixsid')) {
      await saveCookies(cookieStr);
      return cookieStr;
    }
    return null;
  }

  static Future<void> saveCookies(String cookies) =>
      _storage.write(key: _cookieKey, value: cookies);

  static Future<String?> loadCookies() => _storage.read(key: _cookieKey);

  /// Fully wipe VK session: secure storage + WebView cookie jar + WebStorage.
  /// VK sets cookies across multiple origins (.vk.com, login.vk.com, m.vk.com,
  /// st.vk.com) and paths — deleting a single URL leaves stale cookies that
  /// hijack the next login. We nuke the whole cookie jar + DOM storage.
  static Future<void> clearCookies() async {
    await _storage.delete(key: _cookieKey);

    final cm = CookieManager.instance();
    // Primary wipe: kill everything. Safe because this app doesn't rely on
    // any other WebView cookies.
    await cm.deleteAllCookies();

    // Defensive per-host wipe in case some cookies with explicit domain/path
    // survived (observed on older Android WebView versions).
    const vkHosts = [
      'https://vk.com',
      'https://m.vk.com',
      'https://login.vk.com',
      'https://st.vk.com',
      'https://api.vk.com',
      'https://vk.ru',
      'https://m.vk.ru',
    ];
    for (final host in vkHosts) {
      await cm.deleteCookies(url: WebUri(host));
      await cm.deleteCookies(url: WebUri(host), domain: '.vk.com');
      await cm.deleteCookies(url: WebUri(host), domain: '.vk.ru');
    }

    // Clear DOM storage (localStorage/sessionStorage may contain session data).
    try {
      await InAppWebViewController.clearAllCache();
    } catch (_) {
      // older inappwebview versions may not expose this; ignore.
    }
  }

  static Future<bool> hasValidSession() async {
    final cookies = await loadCookies();
    return cookies != null && cookies.contains('remixsid');
  }
}
