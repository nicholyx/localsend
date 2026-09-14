# HarmonyOS (OHOS) port

LocalSend runs on HarmonyOS / OpenHarmony phones. This document explains how
the port is structured, how to build the HAP, and what the known limitations
are.

## Architecture

The port follows the standard [flutter-ohos](https://gitcode.com/openharmony-tpc/flutter_flutter)
tooling (the OpenHarmony SIG fork of Flutter):

| Piece | Location |
| --- | --- |
| OHOS app shell (hvigor, entry ability, module config) | `app/ohos/` |
| Vendored OHOS implementations of federated plugins | `third_party/flutter/` (see its README) |
| OHOS platform channel for app-specific features | `app/ohos/entry/src/main/ets/entryability/LocalsendOhosPlugin.ets` |
| cargokit support for the `ohos-arm64` target (Rust library) | `packages/localsend_isolates/rust_builder/` |

Notes:

- The Rust networking core (HTTP server/client, multicast discovery) runs on
  OHOS unchanged. Only **WebRTC is disabled** on OHOS (`aarch64-unknown-linux-ohos`
  cannot compile the `webrtc` crate yet); the Dart side keeps WebRTC off, and
  `packages/localsend_isolates/rust/src/api/webrtc.rs` carries signature-stable
  stubs for that target.
- Platform detection in Dart uses `Platform.operatingSystem == 'ohos'` (see
  `checkPlatformIsOhos()` in `app/lib/util/native/platform_check.dart`), which
  compiles against the stock Flutter SDK too.
- `open_file` has no OHOS implementation; files/folders are opened through the
  `org.localsend.localsend_app/ohos_file_opener` method channel instead.

## Requirements

- **flutter-ohos SDK**: branch `oh-3.41.9-dev` of
  `https://gitcode.com/openharmony-tpc/flutter_flutter.git` (version-matched to
  the Flutter version in `.fvmrc`). Keep both in sync when bumping Flutter.
- **HarmonyOS Command Line Tools** (hvigor, ohpm, node, SDK) from
  <https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-commandline-get>,
  or DevEco Studio.
- **Rust** with the `aarch64-unknown-linux-ohos` target (`rustup target add aarch64-unknown-linux-ohos`).
- JDK 17.

Environment (adjust the tool home to your Command Line Tools install):

```bash
export TOOL_HOME=/opt/command-line-tools
export DEVECO_SDK_HOME=$TOOL_HOME/sdk
export PATH=$TOOL_HOME/tools/ohpm/bin:$PATH
export PATH=$TOOL_HOME/tools/hvigor/bin:$PATH
export PATH=$TOOL_HOME/tools/node/bin:$PATH
export PATH="$HOME/flutter-ohos/bin:$PATH"   # flutter-ohos SDK
```

## Building

```bash
cd app
flutter pub get
flutter build hap --target-platform ohos-arm64 --debug    # or --release
```

The HAP lands in `app/ohos/entry/build/default/outputs/default/`.

## CI packaging

The **Build HarmonyOS HAP** workflow (`.github/workflows/build_ohos_hap.yml`)
builds the HAP on every manual dispatch and uploads it as a workflow artifact
for manual QA. It is deliberately **not** wired to releases: release packages
require reviewed, signed builds (run it manually once QA passed instead).

### Signing

A HAP must be signed before it installs on a real device. Two options:

1. **CI signing (recommended once stable)** — create an AGC debug certificate
   in DevEco Studio (*File > Project Structure > Signing Configs > Sign in*),
   then add these repository secrets:
   - `OHOS_SIGN_P12_BASE64` — key store (.p12), base64
   - `OHOS_SIGN_CERT_BASE64` — certificate (.cer), base64
   - `OHOS_SIGN_P7B_BASE64` — provisioning profile (.p7b), base64
   - `OHOS_SIGN_KEY_ALIAS`, `OHOS_SIGN_KEY_PASSWORD`, `OHOS_SIGN_STORE_PASSWORD`

   The workflow then produces an `entry-default-signed.hap` you can install
   directly with `hdc install`.
2. **Local signing** — download the unsigned artifact, open it in DevEco
   Studio (*Build > Build App(s)/HAP(s)* with automatic signing enabled), or
   sign it with `hap-sign-tool` from the Command Line Tools.

Install on a connected device:

```bash
hdc install entry-default-signed.hap
```

## Testing

Run the normal checks first (`fvm flutter analyze`, `fvm flutter test`,
`cargo check`) — see `CONTRIBUTING.md`. The CI `test` job runs the same suite.

Manual QA checklist for the HAP (device or emulator):

- [ ] App starts; local device shows its alias and IP
- [ ] Discovery: two devices on the same network see each other
- [ ] Receive: send files from another device, accept, save to default directory
- [ ] Send: pick files (file selector) and send to another device
- [ ] Open a received file / the received folder
- [ ] Settings persist across restarts (alias, theme, save directory)
- [ ] Web send (browser download page) loads from the device IP
- [ ] "Open share settings" / system links behave (no crash)

## Known limitations

- WebRTC (nearby transfer over the signaling server) is unavailable on OHOS.
- `share_handler` (share intents), gallery picking via `photo_manager`, and
  `file_picker` have no OHOS implementations; related entry points degrade
  (file selection uses the OHOS `file_selector` instead).
- Desktop-only features (tray, window manager) are inert on phones, as on Android.
