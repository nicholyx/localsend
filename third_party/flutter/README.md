# Vendored HarmonyOS (OHOS) plugin implementations

These are vendored copies of the OpenHarmony-SIG implementations of Flutter
federated plugins used by LocalSend. Upstream sources:

| Directory | Upstream |
| --- | --- |
| `file_selector_ohos` | https://gitee.com/openharmony-sig/flutter_file_selector (Apache-2.0) |
| `path_provider_ohos` | https://gitee.com/openharmony-sig/flutter_path_provider (Apache-2.0) |
| `permission_handler_ohos` | https://gitee.com/openharmony-sig/flutter_permission_handler (Apache-2.0) |
| `shared_preferences_ohos` | https://github.com/flutter/packages + OpenHarmony-SIG port (BSD-3-Clause) |
| `url_launcher_ohos` | https://gitee.com/openharmony-sig/flutter_url_launcher (Apache-2.0) |
| `flex_color_picker` | https://github.com/rydmike/flex_color_picker (BSD-3-Clause), version 3.8.0 with default cases added to exhaustive `TargetPlatform` switches |

Why vendored: the OHOS plugin implementations are only published as Git
dependencies (or not published to pub.dev at all), and `app/pubspec.yaml`
references them via `path:` so that regular (non-OHOS) Flutter builds are
unaffected — the OHOS platform only gets active when building with the
[flutter-ohos](https://gitee.com/openharmony-sig/flutter_flutter)
fork of the Flutter tool.

`flex_color_picker` is vendored for a different reason: the flutter-ohos fork
adds `TargetPlatform.ohos` to the enum, which breaks exhaustive switches in
unpatched pub packages. The vendored copy adds `default` cases (purely
additive, no behavior change) and is wired in through `dependency_overrides`.

To update a vendored plugin, replace the directory with the matching upstream
release and re-run `fvm flutter pub get` from `app/`.
