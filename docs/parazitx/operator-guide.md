# ParazitX operator guide (self-hosted)

This guide is for operators who run their own ParazitX backend nodes and
distribute Dropweb-compatible profiles via Remnawave (or any subscription
provider that supports custom headers).

ParazitX is a transport bridge, not a VPN provider. Subscriptions remain
the source of user exit nodes (Hysteria2 / Hysteria / etc.) — ParazitX
just helps the client establish a tunnel session through VK Calls
infrastructure when direct outbound access is blocked.

## Components

| Component | Repo | Purpose |
|---|---|---|
| `callfactory` | `enkinvsh/parazitx` | HTTP service exposing `/v1/session` and `/health`; orchestrates per-session VK call workers |
| `vk-tunnel-server` + `hysteria2-vk` | `enkinvsh/parazitx` | Backend pair that terminates the VK tunnel and surfaces a SOCKS/Hysteria endpoint |
| `parazitx-proxy` | `enkinvsh/parazitx/yc-proxy` | Optional Yandex Cloud Function in front of `callfactory` for TSPU-resilient signaling |
| `libparazitx-relay.so` | `enkinvsh/parazitx/relay` | Android relay binary embedded in Dropweb (built per `relay-build.md`) |
| Dropweb client | `dropweb-app` (this repo) | Flutter VPN client; consumes Remnawave subscriptions and the ParazitX manifest |

The client never has compiled-in node hostnames or YC URLs. Everything is
discovered at runtime from subscription headers and a manifest URL.

## Discovery order in the client

For each ParazitX activation the client resolves servers and signaling
relays in this order:

1. **Subscription headers** (Remnawave provider headers on the active
   profile) — operator-pinned values:
   - `dropweb-parazitx-servers: host:port[,host:port,...]`
     A comma-separated list of direct backend nodes (HTTP).
   - `dropweb-parazitx-relays: https://relay1[,https://relay2,...]`
     A comma-separated list of HTTPS signaling relays. Header relays
     fully override manifest relays when present.
   - `dropweb-parazitx-manifest: https://your.example/manifest.json`
     Override URL of the registry manifest. Optional.
2. **Manifest fetch** — when the corresponding header is missing, the
   client fetches the manifest URL from the header above or, if absent,
   the default registry URL `https://sub.dropweb.org/parazitx/manifest.json`.
3. **Default fall-through** — if both header and manifest produce nothing,
   activation fails with `networkError`. There is no compiled hardcoded
   fallback.

Servers from headers are authoritative — the manifest never overrides
operator-supplied servers. The manifest is consulted only to add signaling
relays when the operator has not pinned them.

## Running a node

Each ParazitX node provides:

- HTTP `/v1/session` and `/health` on port `3478` (callfactory).
- The VK tunnel processes (`vk-tunnel-server`, `hysteria2-vk`) bound on
  `127.0.0.1`.

Deployment lives in [`enkinvsh/parazitx/deploy`](https://github.com/enkinvsh/parazitx/tree/main/deploy).
The high-level flow:

```bash
# On the node host (Ubuntu 22.04+)
git clone git@github.com:enkinvsh/parazitx.git /opt/parazitx
cd /opt/parazitx
./deploy/install.sh       # installs systemd units callfactory, vk-tunnel-server, hysteria2-vk
systemctl status callfactory --no-pager
curl -s http://127.0.0.1:3478/health
# expected: {"status":"ok","sessions":0,"max":N}
```

Logs:

```bash
journalctl -u callfactory -f
journalctl -u vk-tunnel-server -f
journalctl -u hysteria2-vk -f
```

Call sessions log to `/var/log/parazitx/<token>/<timestamp>_<id>.log`.

## Publishing your own manifest

If you want clients to discover your nodes via manifest (instead of
subscription headers), serve a JSON file like:

```json
{
  "version": 1,
  "environment": "prod",
  "nodes": [
    {
      "id": "myorg-eu-1",
      "region": "de",
      "host": "pzx-eu-1.example.com",
      "port": 3478,
      "protocol": "parazitx-callfactory-v1",
      "weight": 100,
      "enabled": true,
      "features": ["session-v1", "socks5-local"]
    }
  ],
  "signaling_relays": [
    {
      "id": "myorg-yc-prod",
      "kind": "https-session",
      "url": "https://abcdef.apigw.yandexcloud.net",
      "weight": 100,
      "applies_to": ["myorg-eu-1"]
    }
  ]
}
```

Then point users at it via:

- the `dropweb-parazitx-manifest` header on every profile, or
- a community-wide registry URL hardcoded into your distribution of Dropweb
  (override `_defaultManifestUrl` in `lib/services/parazitx_manager.dart`
  when forking).

### `signaling_relays` kinds

| Kind | Behavior |
|---|---|
| `https-session` | Relay URL is itself a session endpoint. Client `POST`s the encrypted body to `<relay>/v1/session` directly, with **no** `X-Dropweb-Backend` header. The relay decides which backend to use. Use this for Yandex API Gateway or any other "smart" relay that already knows your nodes. |
| `https-passthrough` | Relay forwards to a backend the client tells it about via `X-Dropweb-Backend: host:port`. The client only uses these relays when it also has a backend server (from headers or manifest). Use this for generic L7 proxies. |

Unknown kinds are ignored. Non-HTTPS or hostless URLs are dropped.

## Yandex Cloud (optional, useful inside Russia)

Yandex API Gateway is in many Russian network whitelists. If you want a
TSPU-resilient signaling path, deploy `enkinvsh/parazitx/yc-proxy` and
publish its URL as an `https-session` relay in your manifest.

The function:

- accepts `POST /v1/session` and `POST /v1/logs`,
- forwards them to the backend specified by `PARAZITX_BACKEND` env var
  (typically `http://your.host:3478`) or the per-request
  `X-Dropweb-Backend` header,
- returns the upstream response verbatim.

Deploy with:

```bash
cd /Users/oen/Documents/projects/parazitx/yc-proxy
./deploy.sh   # uses yc serverless function version create
```

Health check:

```bash
curl -s https://<your-function>.apigw.yandexcloud.net/health
# expected: {"status":"ok","sessions":...}
```

Then add it to your manifest as `kind: "https-session"`. See
[infra:zencab-sub/Caddyfile](https://github.com/enkinvsh/parazitx) and
the canonical Dropweb manifest at
`https://sub.dropweb.org/parazitx/manifest.json` for a working example.

## Subscription template — Remnawave

Add the headers you need to your Remnawave host template. Examples:

```yaml
# Pin a backend server, let the client pick relays from the manifest
provider_headers:
  dropweb-parazitx-servers: pzx-eu-1.example.com:3478

# Pin everything explicitly, skip the manifest entirely
provider_headers:
  dropweb-parazitx-servers: pzx-eu-1.example.com:3478,pzx-eu-2.example.com:3478
  dropweb-parazitx-relays:  https://relay-1.example.com,https://relay-2.example.com

# Use only your own manifest
provider_headers:
  dropweb-parazitx-manifest: https://registry.example.com/parazitx.json
```

Headers are picked up from the active profile every time the user toggles
ParazitX, so subscription updates apply on the next activation without
reinstall.

## Log uploading

The "Send ParazitX logs" button in Dropweb posts to `/v1/logs` using the
same discovery rules as activation:

- `dropweb-parazitx-servers` → `http://host:port/v1/logs`
- `dropweb-parazitx-relays`  → `https://relay/v1/logs` (with
  `X-Dropweb-Backend` only when a backend server is also known)
- otherwise → `https-session` relays from the manifest

Ensure your callfactory or YC proxy accepts `POST /v1/logs` if you want
in-app log collection from end users.

## Smoke test checklist

After standing up a node and publishing the manifest:

1. `curl -s http://node:3478/health` returns `status: ok`.
2. Manifest URL serves valid JSON with at least one enabled node.
3. Install a Dropweb build, import a Remnawave profile that uses your
   headers (or no headers + your manifest).
4. Toggle ParazitX. logcat should show:
   - `[ParazitX][activation] resolved: servers=N relays=M`
   - `=== DC TUNNEL CONNECTED ===`
   - `MTU: 1280`, `sessionId=ParazitX`
5. Tap "Send ParazitX logs". A new file should appear under
   `/var/log/parazitx/<token>/` on the receiving node within seconds.
6. Verify some sites load through the tunnel.

If any step fails, check `journalctl -u callfactory --since '5 minutes ago'`
on the node and `adb logcat -d | grep ParazitX` on the device first.

## What is NOT supported on purpose

- **No compiled fallbacks.** The client refuses to connect rather than
  silently using a hardcoded server. Configure the headers or the
  manifest.
- **No traffic relaying through `signaling_relays`.** They handle
  `/v1/session` and `/v1/logs` only — the actual VPN dataplane goes
  through the VK tunnel established by the node.
- **No subscription provider role.** Use Remnawave (or your own
  panel) for that. ParazitX never replaces it.
