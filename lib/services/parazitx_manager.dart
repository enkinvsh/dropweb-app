import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import '../plugins/parazitx_vpn_plugin.dart';
import '../plugins/vk_tunnel_plugin.dart';
import 'crypto_service.dart';
import 'log_buffer.dart';
import 'parazitx_manifest.dart';
import 'vk_auth_service.dart';

/// Typed activation failure reasons.
enum ActivateError {
  /// No VK cookies stored — user needs to log in first.
  noCookies,

  /// HTTP request to callfactory failed (no network / timeout).
  networkError,

  /// Server returned a non-200 status that isn't vkUnauthorized.
  serverError,

  /// VK session is expired / invalid — server responded with
  /// "vk unauthorized" or "timeout waiting".
  vkUnauthorized,

  /// ParazitXVpnService.start() failed (VPN consent denied / prepare failed).
  tunnelError,
}

class ParazitXManager {
  static bool _isActive = false;
  static String? _currentJoinLink;
  static Timer? _rotationTimer;
  static StreamSubscription<String>? _statusSub;
  static const _socksPort = 1080;

  /// Tun MTU used for both initial activation and rotation. Defaults to
  /// the safe ParazitX baseline (1280) which fits inside WebRTC
  /// DataChannel/TURN path MTU without fragmentation. Native side
  /// validates and clamps; out-of-range values fall back to 1280.
  static const _tunMtu = ParazitXVpnPlugin.defaultMtu;

  /// Platform channel to ParazitXVpnService for high-priority "Action
  /// Required" notification when captcha auto-solve stalls in background.
  static const _notificationChannel =
      MethodChannel('app.dropweb/parazitx_notifications');

  /// How long the headless WebView gets to auto-click the captcha before
  /// we surface a heads-up notification.
  ///
  /// Foreground: 10s — auto-solve usually wins.
  /// Background: 2s — Android throttles JS in hidden webviews so auto-solve
  /// won't progress; surface the notification ASAP so the user can bring
  /// the app to foreground (or fullScreenIntent wakes them on lock screen).
  static const _captchaForegroundPromptDelay = Duration(seconds: 10);
  static const _captchaBackgroundPromptDelay = Duration(seconds: 2);
  // TURN allocation lifetime is 10 minutes (RFC 5766 default) and VK's TURN
  // server doesn't honor refresh requests, while ICE restart doesn't work with
  // the VK SFU. The only reliable solution is to rotate to a new call BEFORE
  // the TURN allocation expires. 8 minutes gives a 2-minute safety margin.
  static const _rotationInterval = Duration(minutes: 8);
  static const _sessionRequestTimeout = Duration(seconds: 35);
  static const _manifestFetchTimeout = Duration(seconds: 10);

  /// Per-attempt timeout for HTTPS signaling-relay calls. Kept tighter
  /// than the direct-backend timeout so a misbehaving relay doesn't eat
  /// the whole activation budget — relays are a fallback, not the
  /// happy path.
  static const _relayRequestTimeout = Duration(seconds: 15);

  /// Default Dropweb-operated manifest endpoint. This is a *registry*
  /// URL — the response body lists callfactory nodes; no node hostnames
  /// are compiled into the client. Self-hosted Remnawave deployments can
  /// override this via the [_manifestHeaderName] subscription header to
  /// point at their own manifest.
  ///
  /// Operators wanting an entirely-self-hosted experience should also
  /// set [_serversHeaderName] in their subscription response so the
  /// client never falls back to the Dropweb registry.
  static const _defaultManifestUrl =
      'https://sub.dropweb.org/parazitx/manifest.json';

  /// Subscription HTTP header that lists callfactory `host:port` endpoints
  /// directly (highest priority — used as-is, no manifest fetch performed).
  ///
  /// Must use the `dropweb-` prefix — the profile loader only accepts
  /// dropweb-* provider headers (see Profile.fetchFile in models/profile.dart).
  static const _serversHeaderName = 'dropweb-parazitx-servers';

  /// Subscription HTTP header that overrides the manifest registry URL.
  /// Lets self-hosted Remnawave operators publish their own manifest
  /// without forking the client. Falls back to [_defaultManifestUrl] when
  /// absent.
  static const _manifestHeaderName = 'dropweb-parazitx-manifest';

  /// Subscription HTTP header that lists HTTPS signaling-relay URLs as
  /// an operator override of the manifest's `signaling_relays` block.
  /// Comma-separated; values must be absolute HTTPS URLs. When present
  /// it fully replaces the manifest-derived relay list (highest
  /// priority — same shape as [_serversHeaderName] vs the manifest).
  ///
  /// A relay is signaling-only — it forwards the `/v1/session` request
  /// to a backend node specified by the `X-Dropweb-Backend` header.
  /// Media stays peer-to-peer with VK once the join-link is in hand.
  static const _relaysHeaderName = 'dropweb-parazitx-relays';

  /// Header used by the dialer to tell a signaling relay which backend
  /// `host:port` to forward the request to.
  static const _relayBackendHeaderName = 'X-Dropweb-Backend';

  /// Errors that mean "this server is alive but refused us"; do not
  /// fall through to relays for these — the backend already has a
  /// definitive verdict.
  static bool _shouldTryRelaysOnError(ActivateError err) =>
      err == ActivateError.networkError || err == ActivateError.serverError;

  /// Ordered list of `host:port` endpoints for /v1/session requests.
  /// Populated from the subscription header on first [activate] call,
  /// shuffled once to spread load across the pool, and cached until
  /// [deactivate] clears it.
  static List<String> _servers = [];

  /// Index of the last known working server inside [_servers].
  /// Used as the starting point for rotation/fallback loops so we stick
  /// to a proven endpoint until it fails.
  static int _serverIndex = 0;

  /// Configured signaling relays in priority order. Populated alongside
  /// [_servers] in [activate]; first the subscription header is consulted,
  /// then the manifest's `signaling_relays`. Cleared on [deactivate].
  static List<_RelayCandidate> _relays = const <_RelayCandidate>[];

  static final StreamController<bool> _tunnelReadyCtrl =
      StreamController<bool>.broadcast();
  static final StreamController<String> _captchaCtrl =
      StreamController<String>.broadcast();

  static bool _tunnelReady = false;
  static bool get isTunnelReady => _tunnelReady;
  static Stream<bool> get tunnelReadyStream => _tunnelReadyCtrl.stream;
  static Stream<String> get captchaStream => _captchaCtrl.stream;

  static bool get isActive => _isActive;

  /// Resolve the ordered callfactory endpoint pool plus signaling-relay
  /// fallback list used by [_requestJoinLink].
  ///
  /// Server discovery order (each step short-circuits on the first
  /// non-empty server result):
  ///   1. Subscription header [_serversHeaderName] — explicit `host:port`
  ///      list provided by the operator's panel (Remnawave / self-hosted).
  ///      Highest priority because it lets operators bypass any registry.
  ///   2. Manifest registry — fetched from the URL in
  ///      [_manifestHeaderName] when present, otherwise from
  ///      [_defaultManifestUrl]. Compatible nodes are sorted by
  ///      [ParazitXNodeSelector.selectNode] semantics (highest weight,
  ///      then id) and emitted as `host:port` strings.
  ///
  /// Signaling-relay discovery is layered on top:
  ///   * subscription header [_relaysHeaderName] (if present) is the
  ///     authoritative override and replaces any manifest relays;
  ///   * otherwise the relay list comes from the same manifest fetch
  ///     used to discover servers, scoped to the chosen backend node
  ///     when possible.
  ///
  /// No node hostnames are compiled into the client. Callers must treat an
  /// empty server result as "activation cannot proceed" — the manager
  /// surfaces this to the user as [ActivateError.networkError] rather
  /// than silently pinning a hardcoded server.
  static Future<_DiscoveryResult> _loadServersFromSubscription() async {
    final fromHeader = _serversFromSubscriptionHeader();
    final headerRelays = _relaysFromSubscriptionHeader();

    if (fromHeader.isNotEmpty) {
      developer.log(
        '[ParazitX][activation] using ${fromHeader.length} server(s) from subscription header (head=${fromHeader.first})',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] subscription header servers=${fromHeader.length} head=${fromHeader.first}');
      debugPrint(
          '[ParazitX][activation] header-servers count=${fromHeader.length} head=${fromHeader.first}');

      // Header relays explicitly set: total operator trust, skip manifest.
      if (headerRelays.isNotEmpty) {
        developer.log(
          '[ParazitX][activation] using ${headerRelays.length} relay(s) from subscription header',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] subscription header relays=${headerRelays.length}');
        debugPrint(
            '[ParazitX][activation] header-relays count=${headerRelays.length}');
        return _DiscoveryResult(servers: fromHeader, relays: headerRelays);
      }

      // Header servers but NO header relays: still consult the manifest
      // for signaling relays (header servers stay authoritative — manifest
      // never overrides operator-supplied servers in this path).
      //
      // This covers the common Remnawave deployment where the operator
      // pins backend nodes via `dropweb-parazitx-servers` but expects the
      // Dropweb-published manifest to provide the TSPU-resilient
      // signaling-relay fallback. Without this fetch the client would
      // never attempt a relay even though one is published.
      final manifestUrl = _resolveManifestUrl();
      developer.log(
        '[ParazitX][activation] header servers + no header relays; fetching manifest $manifestUrl for signaling relays only',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] header servers, fetching manifest for relays only ($manifestUrl)');
      debugPrint(
          '[ParazitX][activation] header-servers + no header-relays -> fetch manifest for relays: $manifestUrl');

      final manifestResult = await _fetchManifest(manifestUrl);
      final scopedRelays =
          _manifestRelaysForHeaderServers(manifestResult, fromHeader);
      if (scopedRelays.isNotEmpty) {
        developer.log(
          '[ParazitX][activation] derived ${scopedRelays.length} signaling relay(s) from manifest for header servers',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] manifest-derived relays for header servers: ${scopedRelays.length}');
        debugPrint(
            '[ParazitX][activation] manifest-derived relays for header servers: ${scopedRelays.length}');
      } else {
        developer.log(
          '[ParazitX][activation] manifest yielded no usable relays for header servers',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] manifest yielded no relays for header servers');
        debugPrint(
            '[ParazitX][activation] manifest yielded no relays for header servers');
      }
      return _DiscoveryResult(servers: fromHeader, relays: scopedRelays);
    }

    final manifestUrl = _resolveManifestUrl();
    final manifestResult = await _fetchManifest(manifestUrl);
    final fromManifest = manifestResult.servers;

    // Header relays still win over manifest relays even when servers
    // were discovered via manifest.
    final relays = headerRelays.isNotEmpty
        ? headerRelays
        : manifestResult.relaysForFirstServer();

    if (fromManifest.isNotEmpty) {
      developer.log(
        '[ParazitX][activation] using ${fromManifest.length} server(s) from manifest $manifestUrl (head=${fromManifest.first})',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] manifest servers=${fromManifest.length} head=${fromManifest.first}');
      debugPrint(
          '[ParazitX][activation] manifest-servers count=${fromManifest.length} head=${fromManifest.first}');
      if (relays.isNotEmpty) {
        developer.log(
          '[ParazitX][activation] using ${relays.length} signaling relay(s) (source=${headerRelays.isNotEmpty ? "header" : "manifest"})',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] relays=${relays.length} source=${headerRelays.isNotEmpty ? "header" : "manifest"}');
        debugPrint(
            '[ParazitX][activation] relays=${relays.length} source=${headerRelays.isNotEmpty ? "header" : "manifest"}');
      }
      return _DiscoveryResult(servers: fromManifest, relays: relays);
    }

    developer.log(
      '[ParazitX][activation] no subscription header servers and manifest yielded none; activation will fail',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] no servers discovered (header empty, manifest=$manifestUrl)');
    debugPrint(
        '[ParazitX][activation] no servers discovered (header empty, manifest=$manifestUrl)');
    return _DiscoveryResult(servers: const <String>[], relays: relays);
  }

  /// Parse the `dropweb-parazitx-relays` provider header into a relay
  /// candidate list. Values must be absolute `https://` URLs;
  /// non-HTTPS or malformed entries are dropped silently.
  static List<_RelayCandidate> _relaysFromSubscriptionHeader() {
    try {
      final profile = globalState.config.currentProfile;
      if (profile == null) return const <_RelayCandidate>[];
      final raw = profile.providerHeaders[_relaysHeaderName];
      if (raw == null || raw.isEmpty) return const <_RelayCandidate>[];
      final out = <_RelayCandidate>[];
      var i = 0;
      for (final part in raw.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final uri = Uri.tryParse(trimmed);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          developer.log(
            '[ParazitX][activation] dropping non-HTTPS relay header entry: $trimmed',
            name: 'ParazitX',
          );
          continue;
        }
        // Subscription-header relays predate the manifest's `kind`
        // field and were always assumed to be passthrough relays
        // (they need an X-Dropweb-Backend header). Keep that contract
        // for headers; operators that want session-style relays must
        // declare them in the manifest where `kind` is explicit.
        out.add(_RelayCandidate(
          id: 'header-$i:${uri.host}',
          url: trimmed,
          kind: kParazitXRelayKindHttpsPassthrough,
        ));
        i++;
      }
      return List.unmodifiable(out);
    } catch (e) {
      developer.log(
        '[ParazitX][activation] relays header parse failed: $e',
        name: 'ParazitX',
      );
      return const <_RelayCandidate>[];
    }
  }

  /// Parse the `dropweb-parazitx-servers` provider header into a normalized
  /// `host:port` list. Returns empty when no profile, no header, or the
  /// header parses to nothing usable.
  static List<String> _serversFromSubscriptionHeader() {
    try {
      final profile = globalState.config.currentProfile;
      if (profile == null) return const <String>[];
      final raw = profile.providerHeaders[_serversHeaderName];
      if (raw == null || raw.isEmpty) return const <String>[];
      final servers = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      return servers;
    } catch (e) {
      developer.log(
        '[ParazitX][activation] subscription header parse failed: $e',
        name: 'ParazitX',
      );
      return const <String>[];
    }
  }

  /// Resolve the manifest URL: profile-provided override (per-operator
  /// self-hosted manifest) or the Dropweb default registry.
  static String _resolveManifestUrl() {
    try {
      final profile = globalState.config.currentProfile;
      final override = profile?.providerHeaders[_manifestHeaderName];
      if (override != null && override.isNotEmpty) {
        final trimmed = override.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    } catch (_) {}
    return _defaultManifestUrl;
  }

  /// Fetch [manifestUrl] and return the compatible servers (`host:port`
  /// strings) plus a parsed [ParazitXManifest] for downstream lookups
  /// (e.g. `signaling_relays`).
  ///
  /// Network/parse/timeout failures collapse to an empty result; the
  /// caller is responsible for surfacing the resulting absence-of-servers
  /// as a user-visible activation failure.
  static Future<_ManifestFetchResult> _fetchManifest(String manifestUrl) async {
    final Uri uri;
    try {
      uri = Uri.parse(manifestUrl);
    } catch (e) {
      developer.log(
        '[ParazitX][activation] manifest URL parse failed: $manifestUrl ($e)',
        name: 'ParazitX',
      );
      return _ManifestFetchResult.empty;
    }

    final http.Response response;
    try {
      response = await http.get(uri).timeout(_manifestFetchTimeout);
    } catch (e) {
      developer.log(
        '[ParazitX][activation] manifest fetch failed: $uri ($e)',
        name: 'ParazitX',
      );
      LogBuffer.instance
          .add('[ParazitX][activation] manifest fetch failed: $e');
      return _ManifestFetchResult.empty;
    }

    if (response.statusCode != 200) {
      developer.log(
        '[ParazitX][activation] manifest HTTP ${response.statusCode} from $uri',
        name: 'ParazitX',
      );
      LogBuffer.instance
          .add('[ParazitX][activation] manifest HTTP ${response.statusCode}');
      return _ManifestFetchResult.empty;
    }

    final ParazitXManifest manifest;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('manifest root is not a JSON object');
      }
      manifest = ParazitXManifest.fromJson(decoded);
    } catch (e) {
      developer.log(
        '[ParazitX][activation] manifest parse failed: $e',
        name: 'ParazitX',
      );
      LogBuffer.instance
          .add('[ParazitX][activation] manifest parse failed: $e');
      return _ManifestFetchResult.empty;
    }

    final compatible = manifest.compatibleNodes;
    if (compatible.isEmpty) {
      return _ManifestFetchResult(
        servers: const <String>[],
        manifest: manifest,
        sortedNodes: const <ParazitXNode>[],
      );
    }

    final sorted = [...compatible]..sort((a, b) {
        final byWeight = b.weight.compareTo(a.weight);
        if (byWeight != 0) return byWeight;
        return a.id.compareTo(b.id);
      });

    final seen = <String>{};
    final out = <String>[];
    for (final n in sorted) {
      final endpoint = '${n.host}:${n.port}';
      if (seen.add(endpoint)) out.add(endpoint);
    }
    return _ManifestFetchResult(
      servers: out,
      manifest: manifest,
      sortedNodes: sorted,
    );
  }

  /// Resolve manifest signaling relays for an operator-supplied
  /// `dropweb-parazitx-servers` header list.
  ///
  /// Two paths are folded into one result:
  ///   1. Node-scoped relays: when a manifest node's `host:port` exactly
  ///      matches one of [headerServers], its `relaysForNode(node.id)`
  ///      list applies. Header servers may collide with manifest nodes
  ///      (operators using the same canary as Dropweb publishes); this
  ///      path lets manifest-published relays enrich the dial path.
  ///   2. Standalone session relays: relays of kind `https-session` are
  ///      always usable because they pick a backend themselves. Even
  ///      when their `applies_to` whitelist is scoped to nodes the
  ///      header doesn't reference, they remain a valid fallback —
  ///      they never need [_relayBackendHeaderName].
  ///
  /// Duplicates (same id/url/kind triple) are collapsed in declaration
  /// priority order: node-scoped first, then session-only.
  static List<_RelayCandidate> _manifestRelaysForHeaderServers(
    _ManifestFetchResult manifestResult,
    List<String> headerServers,
  ) {
    final manifest = manifestResult.manifest;
    if (manifest == null) return const <_RelayCandidate>[];

    final headerSet = headerServers.toSet();
    final out = <_RelayCandidate>[];
    final seen = <String>{};

    void addRelay(ParazitXSignalingRelay r) {
      final key = '${r.id}|${r.url}|${r.kind}';
      if (!seen.add(key)) return;
      out.add(_RelayCandidate(id: r.id, url: r.url, kind: r.kind));
    }

    // Path 1: relays for nodes that match one of the header servers
    // (operator pinned a Dropweb-published node by host:port).
    for (final node in manifest.nodes) {
      final endpoint = '${node.host}:${node.port}';
      if (!headerSet.contains(endpoint)) continue;
      for (final r in manifest.relaysForNode(node.id)) {
        addRelay(r);
      }
    }

    // Path 2: standalone session relays — manifest-declared relays of
    // kind `https-session` are dialable without a backend match because
    // the relay URL itself is the session endpoint. Include even when
    // `applies_to` is node-scoped to a node the header didn't list.
    // The HTTPS-only / kind-supported filter is enforced by
    // `relaysForNode`; here we consult `signalingRelays` directly to
    // bypass `applies_to` scoping for the session-kind subset only.
    for (final r in manifest.signalingRelays) {
      if (r.kind != kParazitXRelayKindHttpsSession) continue;
      if (!_isManifestRelayUsable(r)) continue;
      addRelay(r);
    }

    return List.unmodifiable(out);
  }

  /// Mirror of the manifest-side HTTPS/kind filter, applied here when we
  /// reach into `manifest.signalingRelays` directly (bypassing
  /// `relaysForNode`'s scope check). Keeps a single bad relay entry
  /// from poisoning the candidate list.
  static bool _isManifestRelayUsable(ParazitXSignalingRelay r) {
    if (!kParazitXSupportedRelayKinds.contains(r.kind)) return false;
    final uri = Uri.tryParse(r.url.trim());
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  /// Try to obtain session from a single server endpoint.
  /// [server] can be 'host:port' (HTTP) or a full URL (HTTPS).
  /// Returns ok result on success, or error result on failure.
  static Future<_SessionResult> _tryServer(
    String server,
    String body, {
    required Duration timeout,
    bool isHttps = false,
  }) async {
    final uri = isHttps
        ? Uri.parse('$server/v1/session')
        : Uri.parse('http://$server/v1/session');

    final stopwatch = Stopwatch()..start();
    developer.log(
        '[ParazitX][activation] trying server: $server (timeout=${timeout.inSeconds}s)',
        name: 'ParazitX');
    LogBuffer.instance.add('[ParazitX][activation] trying server: $server');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);
    } catch (e) {
      final elapsed = stopwatch.elapsedMilliseconds;
      developer.log(
          '[ParazitX][activation] server $server request failed after ${elapsed}ms: $e',
          name: 'ParazitX');
      LogBuffer.instance.add(
          '[ParazitX][activation] server $server failed: $e (${elapsed}ms)');
      return const _SessionResult.err(ActivateError.networkError);
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    if (response.statusCode == 503) {
      developer.log(
        '[ParazitX][activation] server $server overloaded (503) after ${elapsed}ms, trying next',
        name: 'ParazitX',
      );
      LogBuffer.instance
          .add('[ParazitX][activation] server $server: 503 (${elapsed}ms)');
      return const _SessionResult.err(ActivateError.serverError);
    }

    if (response.statusCode != 200) {
      final respBody = response.body.toLowerCase();
      if (respBody.contains('vk unauthorized') ||
          respBody.contains('timeout waiting') ||
          respBody.contains('check cookies')) {
        developer.log(
          '[ParazitX][activation] server $server: VK unauthorized (${response.statusCode}) after ${elapsed}ms',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] server $server: VK unauthorized (${elapsed}ms)');
        return const _SessionResult.err(ActivateError.vkUnauthorized);
      }
      developer.log(
        '[ParazitX][activation] server $server returned ${response.statusCode} after ${elapsed}ms',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] server $server: ${response.statusCode} (${elapsed}ms)');
      return const _SessionResult.err(ActivateError.serverError);
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      developer.log(
        '[ParazitX][activation] server $server: JSON decode failed after ${elapsed}ms',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    final joinLink = data['join_link'] as String?;
    if (joinLink == null) {
      developer.log(
        '[ParazitX][activation] server $server: missing join_link after ${elapsed}ms',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    developer.log(
      '[ParazitX][activation] server $server: SUCCESS (200) after ${elapsed}ms',
      name: 'ParazitX',
    );
    LogBuffer.instance
        .add('[ParazitX][activation] server $server: OK (${elapsed}ms)');
    return _SessionResult.ok(joinLink, 0);
  }

  /// POST encrypted VK cookies to callfactory and return the join_link,
  /// or an [ActivateError] describing what went wrong.
  ///
  /// Iterates the resolved server pool (subscription header → manifest)
  /// starting at [_serverIndex] so a previously-working endpoint stays
  /// sticky. Returns the first 200 with a join_link, short-circuits on
  /// [ActivateError.vkUnauthorized], or surfaces the last error if every
  /// server failed.
  static Future<_SessionResult> _requestJoinLink() async {
    final stopwatch = Stopwatch()..start();
    developer.log(
      '[ParazitX][activation] _requestJoinLink() started',
      name: 'ParazitX',
    );
    LogBuffer.instance
        .add('[ParazitX][activation] _requestJoinLink: loading cookies');
    debugPrint(
        '[ParazitX][activation] _requestJoinLink() start servers=${_servers.length} relays=${_relays.length}');

    final cookieStopwatch = Stopwatch()..start();
    final cookies = await VkAuthService.loadCookies();
    final cookieElapsed = cookieStopwatch.elapsedMilliseconds;
    if (cookies == null) {
      developer.log(
        '[ParazitX][activation] loadCookies: none (${cookieElapsed}ms) -> noCookies',
        name: 'ParazitX',
      );
      LogBuffer.instance
          .add('[ParazitX][activation] loadCookies: none (${cookieElapsed}ms)');
      return const _SessionResult.err(ActivateError.noCookies);
    }

    developer.log(
      '[ParazitX][activation] loadCookies: ok (${cookieElapsed}ms), encrypting',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] loadCookies ok (${cookieElapsed}ms), encrypting');

    final encryptStopwatch = Stopwatch()..start();
    final encrypted = await CryptoService.encryptCookies(cookies);
    final body = jsonEncode(encrypted);
    final encryptElapsed = encryptStopwatch.elapsedMilliseconds;
    developer.log(
      '[ParazitX][activation] encryptCookies: done (${encryptElapsed}ms), starting server attempts',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] encryptCookies done (${encryptElapsed}ms)');
    LogBuffer.instance.add(
        '[ParazitX][activation] trying ${_servers.length} servers, starting at index $_serverIndex');

    // Try loaded servers first (from subscription or fallback list)
    var lastError = ActivateError.networkError;

    for (var attempt = 0; attempt < _servers.length; attempt++) {
      final idx = (_serverIndex + attempt) % _servers.length;
      final server = _servers[idx];

      developer.log(
        '[ParazitX][activation] server attempt $attempt/${_servers.length}: idx=$idx server=$server',
        name: 'ParazitX',
      );

      final result = await _tryServer(
        server,
        body,
        timeout: _sessionRequestTimeout,
        isHttps: false,
      );

      if (result.error == null) {
        final elapsed = stopwatch.elapsedMilliseconds;
        developer.log(
          '[ParazitX][activation] _requestJoinLink SUCCESS via server $server after ${elapsed}ms',
          name: 'ParazitX',
        );
        LogBuffer.instance
            .add('[ParazitX][activation] _requestJoinLink OK (${elapsed}ms)');
        return _SessionResult.ok(result.joinLink!, idx);
      }

      if (result.error == ActivateError.vkUnauthorized) {
        final elapsed = stopwatch.elapsedMilliseconds;
        developer.log(
          '[ParazitX][activation] VK unauthorized from server $server after ${elapsed}ms, aborting',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] VK unauthorized, aborting (${elapsed}ms)');
        return result;
      }

      lastError = result.error ?? ActivateError.networkError;
    }

    // All direct backend dials failed (or there were no servers).
    // Fall through to signaling relays only when the failure mode is a
    // network/server problem. vkUnauthorized would have already
    // returned above; we never reach the relay loop after a definitive
    // backend rejection.
    if (_relays.isNotEmpty && _shouldTryRelaysOnError(lastError)) {
      final relayResult = await _tryRelays(body, lastError);
      if (relayResult != null) {
        // _tryRelays returns a non-null result either on success
        // (positive ok) or on a definitive failure that should be
        // surfaced (e.g. relay-reported vkUnauthorized).
        return relayResult;
      }
      // null = relays exhausted without a definitive result; keep
      // lastError below.
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    if (_servers.isEmpty && _relays.isEmpty) {
      developer.log(
        '[ParazitX][activation] no servers available after ${elapsed}ms',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] _requestJoinLink: no servers (${elapsed}ms)');
      return const _SessionResult.err(ActivateError.networkError);
    }

    developer.log(
      '[ParazitX][activation] all ${_servers.length} servers + ${_relays.length} relay(s) failed after ${elapsed}ms, lastError=$lastError',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] _requestJoinLink FAILED: $lastError (${elapsed}ms)');
    return _SessionResult.err(lastError);
  }

  /// Try each configured signaling relay in priority order. Used as a
  /// last-ditch fallback after every direct backend dial in [_servers]
  /// returned a network/server error — *and* as the only path when no
  /// backend nodes were discovered but session-kind relays are
  /// available (the relay infrastructure itself is the session
  /// endpoint, no backend required).
  ///
  /// Returns:
  ///   * [_SessionResult.ok] on the first relay that responds with 200 +
  ///     join_link; the [_SessionResult.serverIndex] is set to the
  ///     server index of the backend the relay forwarded to (so the
  ///     stickiness logic still works after a relayed activation),
  ///     or `0` when there is no backend pool (pure session-relay
  ///     deployment).
  ///   * [_SessionResult.err] with [ActivateError.vkUnauthorized] on
  ///     the first relay that propagates that response — same
  ///     short-circuit semantics as direct dials.
  ///   * `null` when every relay failed with a non-definitive error;
  ///     the caller falls back to surfacing [lastError].
  static Future<_SessionResult?> _tryRelays(
    String body,
    ActivateError lastError,
  ) async {
    final hasServers = _servers.isNotEmpty;
    final backendForRelay =
        hasServers ? _servers[_serverIndex % _servers.length] : null;

    // Filter relays we can actually dial in the current backend
    // configuration: passthrough relays need a backend host to forward
    // to, so they're unusable when [_servers] is empty.
    final dialable = _relays
        .where((r) => !r.requiresBackendHeader || backendForRelay != null)
        .toList(growable: false);
    if (dialable.isEmpty) return null;

    developer.log(
      '[ParazitX][activation] direct dials failed ($lastError); trying ${dialable.length} signaling relay(s) backend=${backendForRelay ?? "<none>"}',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] relay fallback: ${dialable.length} relay(s), backend=${backendForRelay ?? "<none>"}');
    debugPrint(
        '[ParazitX][activation] _tryRelays: ${dialable.length} relay(s) lastError=$lastError backend=${backendForRelay ?? "<none>"}');

    for (var i = 0; i < dialable.length; i++) {
      final relay = dialable[i];
      final relayHost = Uri.tryParse(relay.url)?.host ?? '<unparseable>';
      developer.log(
        '[ParazitX][activation] relay attempt ${i + 1}/${dialable.length}: id=${relay.id} kind=${relay.kind} host=$relayHost',
        name: 'ParazitX',
      );

      final result = await _tryRelay(
        relay: relay,
        backend: relay.requiresBackendHeader ? backendForRelay : null,
        body: body,
      );

      if (result.error == null) {
        developer.log(
          '[ParazitX][activation] relay SUCCESS via id=${relay.id} host=$relayHost',
          name: 'ParazitX',
        );
        LogBuffer.instance.add(
            '[ParazitX][activation] relay OK id=${relay.id} host=$relayHost');
        return _SessionResult.ok(
          result.joinLink!,
          hasServers ? _serverIndex % _servers.length : 0,
        );
      }

      if (result.error == ActivateError.vkUnauthorized) {
        developer.log(
          '[ParazitX][activation] relay id=${relay.id} returned vkUnauthorized; aborting',
          name: 'ParazitX',
        );
        LogBuffer.instance
            .add('[ParazitX][activation] relay vkUnauthorized id=${relay.id}');
        return result;
      }
    }

    developer.log(
      '[ParazitX][activation] all ${dialable.length} relay(s) failed',
      name: 'ParazitX',
    );
    return null;
  }

  /// Issue a `/v1/session` POST through a signaling relay.
  ///
  /// When [backend] is non-null, the dialer attaches
  /// `X-Dropweb-Backend: host:port` and the relay is expected to
  /// forward the request to that backend over HTTP, returning the
  /// backend's response verbatim
  /// ([kParazitXRelayKindHttpsPassthrough] semantics).
  ///
  /// When [backend] is null, no forwarding header is sent: the relay
  /// URL itself is the session endpoint
  /// ([kParazitXRelayKindHttpsSession] semantics — e.g. a Yandex API
  /// Gateway that fronts an internal callfactory pool and selects a
  /// backend on its own).
  static Future<_SessionResult> _tryRelay({
    required _RelayCandidate relay,
    required String? backend,
    required String body,
  }) async {
    final base = Uri.tryParse(relay.url);
    if (base == null) {
      developer.log(
        '[ParazitX][activation] relay url unparseable: id=${relay.id}',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.networkError);
    }
    // Append /v1/session to whatever the operator set as the relay
    // path. We collapse a trailing slash so we don't end up with
    // `//v1/session`.
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final uri = base.replace(path: '$basePath/v1/session');
    final relayHost = base.host;

    final stopwatch = Stopwatch()..start();
    developer.log(
      '[ParazitX][activation] dialing relay id=${relay.id} host=$relayHost (timeout=${_relayRequestTimeout.inSeconds}s)',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
        '[ParazitX][activation] relay dial id=${relay.id} host=$relayHost');
    debugPrint(
        '[ParazitX][activation] _tryRelay id=${relay.id} kind=${relay.kind} host=$relayHost backend=${backend ?? "<none>"}');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (backend != null) _relayBackendHeaderName: backend,
    };

    final http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: body)
          .timeout(_relayRequestTimeout);
    } catch (e) {
      final elapsed = stopwatch.elapsedMilliseconds;
      developer.log(
        '[ParazitX][activation] relay id=${relay.id} request failed after ${elapsed}ms: $e',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
          '[ParazitX][activation] relay id=${relay.id} failed (${elapsed}ms)');
      return const _SessionResult.err(ActivateError.networkError);
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    if (response.statusCode != 200) {
      final respBody = response.body.toLowerCase();
      if (respBody.contains('vk unauthorized') ||
          respBody.contains('timeout waiting') ||
          respBody.contains('check cookies')) {
        developer.log(
          '[ParazitX][activation] relay id=${relay.id} reported vkUnauthorized (${response.statusCode}) after ${elapsed}ms',
          name: 'ParazitX',
        );
        return const _SessionResult.err(ActivateError.vkUnauthorized);
      }
      developer.log(
        '[ParazitX][activation] relay id=${relay.id} returned ${response.statusCode} after ${elapsed}ms',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      developer.log(
        '[ParazitX][activation] relay id=${relay.id} JSON decode failed after ${elapsed}ms',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    final joinLink = data['join_link'] as String?;
    if (joinLink == null) {
      developer.log(
        '[ParazitX][activation] relay id=${relay.id} missing join_link after ${elapsed}ms',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    developer.log(
      '[ParazitX][activation] relay id=${relay.id} SUCCESS (200) after ${elapsed}ms',
      name: 'ParazitX',
    );
    return _SessionResult.ok(joinLink, 0);
  }

  /// Activation end-to-end timeout. Prevents hanging at any stage.
  /// Set to 60 seconds to allow for slow networks + server delays.
  static const _activationTimeout = Duration(seconds: 60);

  /// Activate ParazitX mode:
  /// 1. Load stored VK cookies
  /// 2. Encrypt them with X25519+AES-GCM (forward secrecy)
  /// 3. POST to callfactory → receive join_link
  /// 4. Hand joinLink to ParazitXVpnService (in `:parazitx` process) which
  ///    owns the whole pipeline: spawns relay, waits for TUNNEL_CONNECTED,
  ///    brings up tun + tun2socks.
  ///
  /// Returns null on success, or an [ActivateError] describing what went wrong.
  static Future<ActivateError?> activate() async {
    final stopwatch = Stopwatch()..start();
    developer.log(
        '[ParazitX][activation] activate() called, isActive=$_isActive',
        name: 'ParazitX');
    LogBuffer.instance
        .add('[ParazitX][activation] activate() started, isActive=$_isActive');
    debugPrint('[ParazitX][activation] activate() called isActive=$_isActive');
    if (_isActive) {
      developer.log('[ParazitX][activation] already active, returning null',
          name: 'ParazitX');
      return null;
    }

    // Register lifecycle observer so background-captcha logic can fire.
    _ensureLifecycleObserver();
    developer.log('[ParazitX][activation] lifecycle observer ensured',
        name: 'ParazitX');

    // Resolve server pool + signaling relays: subscription-header
    // overrides → manifest → empty (causes _requestJoinLink to fail
    // with networkError).
    if (_servers.isEmpty) {
      developer.log(
          '[ParazitX][activation] resolving server pool (header → manifest)',
          name: 'ParazitX');
      final discovery = await _loadServersFromSubscription();
      _servers = discovery.servers;
      _relays = discovery.relays;
      _serverIndex = 0;
      developer.log(
          '[ParazitX][activation] server list resolved: count=${_servers.length} head=${_servers.isEmpty ? "<none>" : _servers.first} relays=${_relays.length}',
          name: 'ParazitX');
      LogBuffer.instance.add(
          '[ParazitX][activation] servers resolved: count=${_servers.length} head=${_servers.isEmpty ? "<none>" : _servers.first} relays=${_relays.length}');
      debugPrint(
          '[ParazitX][activation] resolved: servers=${_servers.length} head=${_servers.isEmpty ? "<none>" : _servers.first} relays=${_relays.length}');
    } else {
      developer.log(
          '[ParazitX][activation] reusing cached servers: count=${_servers.length} head=${_servers.first} idx=$_serverIndex relays=${_relays.length}',
          name: 'ParazitX');
    }

    // Request join link with timeout guard
    developer.log(
        '[ParazitX][activation] requesting join link (timeout=${_activationTimeout.inSeconds}s)',
        name: 'ParazitX');
    LogBuffer.instance.add(
        '[ParazitX][activation] requesting join link, timeout=${_activationTimeout.inSeconds}s');

    final _SessionResult session;
    try {
      session = await _requestJoinLink().timeout(
        _activationTimeout,
        onTimeout: () {
          developer.log(
              '[ParazitX][activation] join link request TIMED OUT after ${_activationTimeout.inSeconds}s',
              name: 'ParazitX');
          LogBuffer.instance.add(
              '[ParazitX][activation] join link TIMEOUT (${_activationTimeout.inSeconds}s exceeded)');
          return const _SessionResult.err(ActivateError.networkError);
        },
      );
    } catch (e) {
      developer.log('[ParazitX][activation] join link request threw: $e',
          name: 'ParazitX');
      LogBuffer.instance.add('[ParazitX][activation] join link threw: $e');
      return ActivateError.networkError;
    }

    if (session.error != null) {
      final elapsed = stopwatch.elapsedMilliseconds;
      developer.log(
          '[ParazitX][activation] session error=${session.error} after ${elapsed}ms',
          name: 'ParazitX');
      LogBuffer.instance.add(
          '[ParazitX][activation] activate failed: ${session.error} (${elapsed}ms)');
      return session.error;
    }

    final joinLink = session.joinLink!;
    _currentJoinLink = joinLink;
    _serverIndex = session.serverIndex!;
    developer.log(
        '[ParazitX][activation] join link received, subscribing to relay status',
        name: 'ParazitX');
    LogBuffer.instance.add('[ParazitX][activation] join link ok, subscribing');

    // Subscribe BEFORE start so we don't miss the first CONNECTING status
    // (the service broadcasts synchronously on startForegroundService).
    _subscribeToRelayStatus();
    developer.log('[ParazitX][activation] relay status subscribed',
        name: 'ParazitX');

    // Start VPN service
    final pluginStopwatch = Stopwatch()..start();
    developer.log(
        '[ParazitX][activation] plugin.start: BEFORE (socksPort=$_socksPort, mtu=$_tunMtu)',
        name: 'ParazitX');
    LogBuffer.instance
        .add('[ParazitX][activation] plugin.start: BEFORE (mtu=$_tunMtu)');

    try {
      await ParazitXVpnPlugin.start(
        joinLink: joinLink,
        socksPort: _socksPort,
        mtu: _tunMtu,
      );
    } on PlatformException catch (e) {
      final ms = pluginStopwatch.elapsedMilliseconds;
      developer.log(
          '[ParazitX][activation] plugin.start: FAILED (${ms}ms) code=${e.code}, message=${e.message}',
          name: 'ParazitX');
      LogBuffer.instance.add(
          '[ParazitX][activation] plugin.start FAILED (${ms}ms): ${e.code} ${e.message}');
      await _statusSub?.cancel();
      _statusSub = null;
      return ActivateError.tunnelError;
    }
    developer.log(
        '[ParazitX][activation] plugin.start: AFTER ok (${pluginStopwatch.elapsedMilliseconds}ms)',
        name: 'ParazitX');
    LogBuffer.instance.add(
        '[ParazitX][activation] plugin.start: AFTER ok (${pluginStopwatch.elapsedMilliseconds}ms)');

    _isActive = true;
    _startRotationTimer();
    final elapsed = stopwatch.elapsedMilliseconds;
    developer.log('[ParazitX][activation] activate() succeeded in ${elapsed}ms',
        name: 'ParazitX');
    LogBuffer.instance
        .add('[ParazitX][activation] activate SUCCESS (${elapsed}ms total)');
    return null;
  }

  static void _subscribeToRelayStatus() {
    LogBuffer.instance.attachNativeChannel();
    _statusSub?.cancel();
    _statusSub = VkTunnelPlugin.statusStream.listen((status) {
      developer.log('relay status: $status', name: 'ParazitX');
      LogBuffer.instance.add('status: $status');

      final captchaUrl = TunnelStatus.captchaUrl(status);
      if (captchaUrl != null) {
        _captchaCtrl.add(captchaUrl);
        unawaited(_solveCaptchaAutomatically(captchaUrl));
        return;
      }

      if (TunnelStatus.isTunnelReady(status)) {
        if (!_tunnelReady) {
          _tunnelReady = true;
          _tunnelReadyCtrl.add(true);
        }
        // Reset backoff on successful tunnel connection
        if (_reconnectAttempt > 0) {
          developer.log(
            'Tunnel ready: resetting reconnect backoff (was attempt '
            '$_reconnectAttempt, ${_currentBackoff.inSeconds}s)',
            name: 'ParazitX',
          );
          LogBuffer.instance.add(
            'Tunnel ready: resetting reconnect backoff '
            '(attempt=$_reconnectAttempt)',
          );
          _reconnectAttempt = 0;
          _currentBackoff = _minBackoff;
        }
      } else if (TunnelStatus.isFailure(status)) {
        developer.log(
          'tunnel failure: $status, scheduling reconnect',
          name: 'ParazitX',
        );
        if (_tunnelReady) {
          _tunnelReady = false;
          _tunnelReadyCtrl.add(false);
        }
        unawaited(_reconnectAfterFailure());
      }
    });
  }

  /// Headless WebView used to auto-click VK's "I'm not a robot" checkbox.
  /// Stays alive while the captcha page is loading, then is disposed once
  /// the relay accepts the token (or after a hard timeout) so we don't
  /// leak native resources between calls.
  static HeadlessInAppWebView? _captchaWebView;
  static String? _solvingCaptchaUrl;
  static Timer? _captchaTimeoutTimer;
  static Timer? _captchaForegroundPromptTimer;
  static bool _actionNotificationShown = false;
  static StreamSubscription<String>? _captchaStatusSub;

  /// URL of the captcha currently being auto-solved. Tracked separately
  /// from [_solvingCaptchaUrl] so the lifecycle observer can restart
  /// auto-solve when the app returns to foreground (after WebView JS was
  /// throttled in background).
  static String? _pendingCaptchaUrl;

  /// Tracks app foreground/background state for captcha prompt timing
  /// and auto-solve restart logic. Updated by [_ParazitXLifecycleObserver].
  static bool _isAppInForeground = true;

  /// Singleton lifecycle observer. Lazily registered on first [activate]
  /// call, unregistered on [deactivate]. Bridges Flutter's app lifecycle
  /// events into this otherwise-static manager.
  static _ParazitXLifecycleObserver? _lifecycleObserver;

  static void _ensureLifecycleObserver() {
    if (_lifecycleObserver != null) return;
    final observer = _ParazitXLifecycleObserver();
    _lifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  static void _removeLifecycleObserver() {
    final observer = _lifecycleObserver;
    if (observer == null) return;
    WidgetsBinding.instance.removeObserver(observer);
    _lifecycleObserver = null;
  }

  /// Called by [_ParazitXLifecycleObserver] when app lifecycle changes.
  /// On returning to foreground with a pending captcha, restart auto-solve
  /// because the previous WebView was likely throttled by Android.
  static void _onAppLifecycleStateChanged(AppLifecycleState state) {
    final wasForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (_isAppInForeground && !wasForeground && _pendingCaptchaUrl != null) {
      developer.log(
        'App returned to foreground with pending captcha, '
        'restarting auto-solve',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
        'App foregrounded with pending captcha, restarting auto-solve',
      );
      _restartCaptchaAutoSolve();
    }
  }

  /// Dispose any in-flight WebView and re-spawn auto-solve for the same
  /// pending captcha URL. Used when the app comes back to foreground —
  /// the previous WebView's JS may have been frozen by Android Doze.
  static void _restartCaptchaAutoSolve() {
    final url = _pendingCaptchaUrl;
    if (url == null) return;

    unawaited(() async {
      // _disposeCaptchaWebView() clears _pendingCaptchaUrl, so re-set it
      // before re-entering _solveCaptchaAutomatically().
      await _disposeCaptchaWebView();
      _pendingCaptchaUrl = url;
      await _solveCaptchaAutomatically(url);
    }());
  }

  static Future<void> _showActionRequiredNotification() async {
    if (_actionNotificationShown) return;
    _actionNotificationShown = true;
    try {
      await _notificationChannel.invokeMethod<void>('showActionRequired');
    } on PlatformException catch (e) {
      developer.log('showActionRequired failed: ${e.message}',
          name: 'ParazitX');
      _actionNotificationShown = false;
    }
  }

  static Future<void> _dismissActionRequiredNotification() async {
    if (!_actionNotificationShown) return;
    _actionNotificationShown = false;
    try {
      await _notificationChannel.invokeMethod<void>('dismissActionRequired');
    } on PlatformException catch (e) {
      developer.log('dismissActionRequired failed: ${e.message}',
          name: 'ParazitX');
    }
  }

  /// Open a hidden InAppWebView, load the captcha proxy URL, and click the
  /// "I'm not a robot" checkbox automatically. The relay running on
  /// 127.0.0.1:NNNN intercepts the resulting `captchaNotRobot.check` call
  /// and proceeds with auth — so we never need to show UI to the user.
  ///
  /// The manual visible-WebView flow is kept as a fallback (UI listens to
  /// [captchaStream] and opens it) in case auto-solve fails or VK switches
  /// to a puzzle captcha.
  static Future<void> _solveCaptchaAutomatically(String url) async {
    // Avoid spinning up a second WebView for the same URL: VK may emit
    // CAPTCHA: repeatedly until the token is delivered.
    if (_solvingCaptchaUrl == url && _captchaWebView != null) {
      developer.log(
        'Auto-solve already running for $url, skipping',
        name: 'ParazitX',
      );
      return;
    }

    await _disposeCaptchaWebView();
    _solvingCaptchaUrl = url;
    _pendingCaptchaUrl = url;

    developer.log('Auto-solving captcha: $url', name: 'ParazitX');
    LogBuffer.instance.add('Auto-solving captcha: $url');

    const injectScript = '''
(function() {
  if (window.__parazitxAutoClickInstalled) return;
  window.__parazitxAutoClickInstalled = true;

  var attempts = 0;
  var maxAttempts = 40; // ~10s at 250ms

  function tryClick() {
    attempts++;
    var selectors = [
      'input[type="checkbox"]',
      '.vkc__Checkbox__input',
      '[class*="Checkbox__input"]',
      '[class*="checkbox"] input',
      'input[name*="captcha"]',
    ];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el) {
        try {
          el.click();
          console.log('[parazitx] clicked captcha selector:', selectors[i]);
          return true;
        } catch (e) {
          console.log('[parazitx] click failed:', e);
        }
      }
    }
    if (attempts < maxAttempts) {
      setTimeout(tryClick, 250);
    } else {
      console.log('[parazitx] gave up auto-click after', attempts, 'tries');
    }
    return false;
  }

  if (document.readyState === 'complete' ||
      document.readyState === 'interactive') {
    tryClick();
  } else {
    document.addEventListener('DOMContentLoaded', tryClick);
    window.addEventListener('load', tryClick);
  }
})();
''';

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
      ),
      onLoadStop: (controller, _) async {
        developer.log(
          'Captcha page loaded, injecting click',
          name: 'ParazitX',
        );
        LogBuffer.instance.add('Captcha page loaded, injecting click');
        try {
          await controller.evaluateJavascript(source: injectScript);
        } catch (e) {
          developer.log('Captcha JS inject failed: $e', name: 'ParazitX');
        }
      },
      onReceivedError: (_, __, error) {
        developer.log(
          'Captcha WebView error: ${error.description}',
          name: 'ParazitX',
        );
        LogBuffer.instance.add('Captcha WebView error: ${error.description}');
      },
      onConsoleMessage: (_, message) {
        if (message.message.contains('parazitx')) {
          developer.log(
            'Captcha console: ${message.message}',
            name: 'ParazitX',
          );
        }
      },
    );

    _captchaWebView = webView;

    // Tear the WebView down as soon as the relay says the captcha was
    // solved (or the tunnel goes ready / fails). We only listen for the
    // duration of the auto-solve attempt so we don't fight the main
    // status subscription.
    await _captchaStatusSub?.cancel();
    _captchaStatusSub = VkTunnelPlugin.statusStream.listen((status) {
      if (status.startsWith('Captcha solved') ||
          TunnelStatus.isTunnelReady(status) ||
          TunnelStatus.isFailure(status)) {
        developer.log(
          'Captcha resolved by relay (status=$status), disposing WebView',
          name: 'ParazitX',
        );
        unawaited(_disposeCaptchaWebView());
      }
    });

    _captchaForegroundPromptTimer?.cancel();
    final promptDelay = _isAppInForeground
        ? _captchaForegroundPromptDelay
        : _captchaBackgroundPromptDelay;
    _captchaForegroundPromptTimer = Timer(promptDelay, () {
      if (_captchaWebView == null) return;
      developer.log(
        'Captcha unresolved after ${promptDelay.inSeconds}s '
        '(foreground=$_isAppInForeground), '
        'surfacing action-required notification',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
        'Captcha unresolved >${promptDelay.inSeconds}s '
        '(foreground=$_isAppInForeground), showing action notification',
      );
      unawaited(_showActionRequiredNotification());
    });

    // Hard timeout: 30s. If VK switched to a puzzle or our selectors
    // missed, the visible CaptchaScreen (subscribed to captchaStream)
    // remains as a fallback path for the user.
    _captchaTimeoutTimer = Timer(const Duration(seconds: 30), () {
      developer.log(
        'Auto-solve timeout for $url, disposing WebView',
        name: 'ParazitX',
      );
      LogBuffer.instance.add('Captcha auto-solve timeout');
      unawaited(_disposeCaptchaWebView());
    });

    try {
      await webView.run();
    } catch (e) {
      developer.log('Headless WebView run failed: $e', name: 'ParazitX');
      LogBuffer.instance.add('Headless WebView run failed: $e');
      await _disposeCaptchaWebView();
    }
  }

  static Future<void> _disposeCaptchaWebView() async {
    _captchaTimeoutTimer?.cancel();
    _captchaTimeoutTimer = null;
    _captchaForegroundPromptTimer?.cancel();
    _captchaForegroundPromptTimer = null;
    await _captchaStatusSub?.cancel();
    _captchaStatusSub = null;
    _solvingCaptchaUrl = null;
    _pendingCaptchaUrl = null;
    final wv = _captchaWebView;
    _captchaWebView = null;
    if (wv != null) {
      try {
        await wv.dispose();
      } catch (e) {
        developer.log('Failed to dispose captcha WebView: $e',
            name: 'ParazitX');
      }
    }
    await _dismissActionRequiredNotification();
  }

  /// Tear down the VpnService (which tears down relay + tun2socks
  /// internally) and clear local state.
  static Future<void> deactivate() async {
    _stopRotationTimer();
    _reconnectDebounce?.cancel();
    _reconnectDebounce = null;
    _reconnectAttempt = 0;
    _currentBackoff = _minBackoff;
    await _statusSub?.cancel();
    _statusSub = null;
    await _disposeCaptchaWebView();
    _removeLifecycleObserver();
    try {
      await ParazitXVpnPlugin.stop();
    } on PlatformException catch (e) {
      developer.log('vpn stop failed: ${e.message}', name: 'ParazitX');
    }
    _isActive = false;
    _currentJoinLink = null;
    _servers = [];
    _relays = const <_RelayCandidate>[];
    _serverIndex = 0;
    if (_tunnelReady) {
      _tunnelReady = false;
      _tunnelReadyCtrl.add(false);
    }
  }

  /// Returns last known tunnel status from the live stream. The service
  /// owns the authoritative state — ask for a rebroadcast by re-listening
  /// (the native EventChannel does so automatically on first listener).
  static String getStatus() {
    if (!_isActive) return 'inactive';
    return _tunnelReady
        ? TunnelStatus.tunnelConnected
        : TunnelStatus.connecting;
  }

  static void _startRotationTimer() {
    _stopRotationTimer();
    _rotationTimer = Timer.periodic(_rotationInterval, (_) async {
      await _rotateCall();
    });
  }

  static void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  /// Periodic rotation: ask callfactory for a new join_link and hand it to
  /// the running VpnService (which forwards it to relay as a fresh AUTH,
  /// reusing the same process + tun).
  static Future<void> _rotateCall() async {
    if (!_isActive) {
      developer.log('rotateCall: not active, skipping', name: 'ParazitX');
      return;
    }
    if (_servers.isEmpty) {
      developer.log('rotateCall: no servers, skipping', name: 'ParazitX');
      LogBuffer.instance.add('rotateCall: no servers, skipping');
      return;
    }

    final session = await _requestJoinLink();
    if (session.error != null) {
      developer.log(
        'Rotation failed: ${session.error}',
        name: 'ParazitX',
      );
      LogBuffer.instance.add('Rotation failed: ${session.error}');
      return;
    }

    final newJoinLink = session.joinLink!;
    developer.log('rotateCall: got new joinLink', name: 'ParazitX');

    try {
      await ParazitXVpnPlugin.start(
        joinLink: newJoinLink,
        socksPort: _socksPort,
        mtu: _tunMtu,
      );
      _currentJoinLink = newJoinLink;
      _serverIndex = session.serverIndex!;
      developer.log('Rotation successful', name: 'ParazitX');
      LogBuffer.instance.add('Rotation successful, new call started');
    } on PlatformException catch (e) {
      developer.log('Rotation vpn start failed: ${e.message}',
          name: 'ParazitX');
      LogBuffer.instance.add('Rotation vpn start failed: ${e.message}');
    }
  }

  /// Debounce timer to prevent reconnect spam on rapid failures.
  static Timer? _reconnectDebounce;

  /// Minimum backoff delay before first reconnect attempt.
  static const _minBackoff = Duration(seconds: 2);

  /// Maximum backoff delay (cap) — exponential growth stops here.
  static const _maxBackoff = Duration(seconds: 60);

  /// Number of consecutive reconnect attempts since last successful tunnel.
  /// Reset to 0 in [_subscribeToRelayStatus] when tunnel becomes ready.
  static int _reconnectAttempt = 0;

  /// Current backoff delay. Doubles on each failure, capped at [_maxBackoff],
  /// resets to [_minBackoff] on successful tunnel connection.
  static Duration _currentBackoff = _minBackoff;

  /// Auto-reconnect after tunnel failure with exponential backoff.
  /// Delay sequence: 2s → 4s → 8s → 16s → 32s → 60s (capped).
  /// Resets to 2s on successful tunnel connection.
  static Future<void> _reconnectAfterFailure() async {
    _reconnectDebounce?.cancel();

    _reconnectAttempt += 1;
    final delay = _currentBackoff;

    developer.log(
      'Auto-reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
      'Auto-reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
    );

    // Compute next backoff: double, capped at _maxBackoff.
    final nextSeconds = delay.inSeconds * 2;
    _currentBackoff = nextSeconds >= _maxBackoff.inSeconds
        ? _maxBackoff
        : Duration(seconds: nextSeconds);

    _reconnectDebounce = Timer(delay, () async {
      if (!_isActive) {
        developer.log('Reconnect aborted: not active', name: 'ParazitX');
        LogBuffer.instance.add('Reconnect aborted: not active');
        return;
      }

      developer.log('Auto-reconnect: attempting new session', name: 'ParazitX');
      LogBuffer.instance.add('Auto-reconnect: attempting new session');

      // Clear joinLink so we know if rotation actually succeeded
      final oldJoinLink = _currentJoinLink;
      _currentJoinLink = null;

      await _rotateCall();

      // If rotation didn't set a new joinLink, do full reactivate
      if (_currentJoinLink == null) {
        developer.log(
          'Reconnect: rotation failed, trying full reactivate',
          name: 'ParazitX',
        );
        LogBuffer.instance
            .add('Reconnect: rotation failed, trying full reactivate');
        _isActive = false;
        final error = await activate();
        if (error != null) {
          developer.log('Reconnect: full reactivate failed: $error',
              name: 'ParazitX');
          LogBuffer.instance.add('Reconnect: full reactivate failed: $error');
          // Restore old joinLink for next retry attempt
          _currentJoinLink = oldJoinLink;
        }
      } else {
        LogBuffer.instance.add('Reconnect: rotation successful');
      }
    });
  }
}

/// Bridges Flutter's [WidgetsBindingObserver] callbacks into the static
/// [ParazitXManager]. Registered while the tunnel is active; tells the
/// manager when the app moves between foreground and background so we
/// can adjust captcha-prompt timing and restart auto-solve after Doze.
class _ParazitXLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ParazitXManager._onAppLifecycleStateChanged(state);
  }
}

/// Internal description of a signaling-relay candidate the dialer can
/// fall back to when direct backend dialing fails.
///
/// `url` is an absolute HTTPS endpoint; `id` is a stable label used in
/// logs (manifest id when available, host of the URL when the operator
/// supplied a raw URL via subscription header).
///
/// `kind` mirrors [ParazitXSignalingRelay.kind] and decides whether the
/// dialer must include the `X-Dropweb-Backend` forwarding header
/// ([kParazitXRelayKindHttpsPassthrough]) or treat the relay URL itself
/// as the session endpoint ([kParazitXRelayKindHttpsSession]).
class _RelayCandidate {
  const _RelayCandidate({
    required this.id,
    required this.url,
    required this.kind,
  });
  final String id;
  final String url;
  final String kind;

  /// True when the dialer must attach an `X-Dropweb-Backend: host:port`
  /// header so the relay knows where to forward the request. Session
  /// relays handle backend selection on their own and reject (or just
  /// ignore) the header.
  bool get requiresBackendHeader => kind == kParazitXRelayKindHttpsPassthrough;
}

/// Aggregate of the data discovery returns: server endpoints
/// (`host:port`) plus signaling relays scoped to the chosen backend.
class _DiscoveryResult {
  const _DiscoveryResult({
    required this.servers,
    required this.relays,
  });
  final List<String> servers;
  final List<_RelayCandidate> relays;
}

/// Aggregate of a manifest fetch: caller-friendly server list plus the
/// parsed manifest so downstream code can look up scoped data
/// (e.g. signaling relays for the first chosen node).
class _ManifestFetchResult {
  const _ManifestFetchResult({
    required this.servers,
    required this.manifest,
    required this.sortedNodes,
  });

  static const empty = _ManifestFetchResult(
    servers: <String>[],
    manifest: null,
    sortedNodes: <ParazitXNode>[],
  );

  final List<String> servers;
  final ParazitXManifest? manifest;

  /// Compatible nodes in selection priority order (weight desc, id asc).
  /// Used to scope manifest signaling relays to the *primary* node we'd
  /// dial first; relays whose `applies_to` doesn't include that node
  /// still work for the others because `relaysForFirstServer` folds the
  /// same priority over them.
  final List<ParazitXNode> sortedNodes;

  /// Resolve the list of relays that apply to whichever backend node
  /// the dialer would try first. Empty when no manifest, no relays, or
  /// no compatible nodes.
  List<_RelayCandidate> relaysForFirstServer() {
    final m = manifest;
    if (m == null || sortedNodes.isEmpty) return const <_RelayCandidate>[];
    final primary = sortedNodes.first;
    return m
        .relaysForNode(primary.id)
        .map((r) => _RelayCandidate(id: r.id, url: r.url, kind: r.kind))
        .toList(growable: false);
  }
}

class _SessionResult {
  const _SessionResult.ok(String link, int idx)
      : joinLink = link,
        serverIndex = idx,
        error = null;
  const _SessionResult.err(ActivateError err)
      : joinLink = null,
        serverIndex = null,
        error = err;

  final String? joinLink;
  final int? serverIndex;
  final ActivateError? error;
}
