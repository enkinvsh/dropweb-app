# Building `libparazitx-relay.so`

The Android relay binary embedded in the Dropweb APK
(`android/app/src/main/jniLibs/arm64-v8a/libparazitx-relay.so`) is built from
the vendored relay package in the [enkinvsh/parazitx](https://github.com/enkinvsh/parazitx)
repository under `relay/`. This binary is intentionally out of the Dropweb
source tree (`.gitignore`d) — it is produced from a separate Go module and
copied in.

## Source

- Repo: `git@github.com:enkinvsh/parazitx.git`
- Path: `relay/`
- Module: `github.com/enkinvsh/parazitx/relay`

## Prerequisites

- Go 1.26 or newer (matches `relay/go.mod`).
- macOS or Linux build host. CGO is not required for the Android arm64 build
  used by Dropweb today.
- Dropweb checkout at `/Users/oen/Documents/projects/dropweb-app` (or your
  equivalent path).

## Build

```bash
git clone git@github.com:enkinvsh/parazitx.git ~/parazitx
cd ~/parazitx/relay

go test ./tunnel/... -race -count=1
go vet ./...

GOOS=linux GOARCH=arm64 go build \
  -trimpath -ldflags='-s -w' \
  -o /tmp/libparazitx-relay.arm64.so \
  .

file /tmp/libparazitx-relay.arm64.so
# expected: ELF 64-bit LSB executable, ARM aarch64
```

## Install into Dropweb

```bash
cp /tmp/libparazitx-relay.arm64.so \
  /Users/oen/Documents/projects/dropweb-app/android/app/src/main/jniLibs/arm64-v8a/libparazitx-relay.so

shasum -a 256 \
  /Users/oen/Documents/projects/dropweb-app/android/app/src/main/jniLibs/arm64-v8a/libparazitx-relay.so
```

The Dropweb Gradle build keeps `useLegacyPackaging = true` so the `.so`
extracts to `nativeLibraryDir`, where Android allows `ProcessBuilder` to
`exec()` it. Do not change this flag.

## Other Android ABIs

`relay/` builds the same way for armeabi-v7a if a fat APK is ever needed:

```bash
GOOS=linux GOARCH=arm GOARM=7 go build -trimpath -ldflags='-s -w' \
  -o /tmp/libparazitx-relay.arm.so .
```

Dropweb currently ships arm64 only. Do not bundle other ABIs without
explicit need — Pixel 10 is arm64 and universal APKs are forbidden by the
project conventions.

## Verify after install

After copying the new `.so`, build and install Dropweb:

```bash
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
cd /Users/oen/Documents/projects/dropweb-app

flutter build apk \
  --split-per-abi \
  --target-platform android-arm64 \
  --release \
  --dart-define=CORE_VERSION=1.19.18 \
  --dart-define=APP_ENV=pre

adb shell am force-stop app.dropweb
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Check device logcat for `ParazitXRelay` and confirm:

- `relay: SOCKS5 on 127.0.0.1:1080`
- `=== DC TUNNEL CONNECTED ===`
- `tun established fd=... mtu=1280`

## Why we vendored

Earlier the relay was pulled from the upstream `kulikov0/whitelist-bypass`
checkout, which made the binary unreproducible from our repos and tied it
to a third-party module path. Vendoring the relay into
`github.com/enkinvsh/parazitx/relay` (with our `tunnel.VP8DataTunnel`
recv-timestamp helpers, DNS response cache, and the SOCKS UDP header
aliasing fix) lets us build the binary entirely from our own sources.
