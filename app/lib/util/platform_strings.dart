import 'package:flutter/foundation.dart';

extension TargetPlatformExt on TargetPlatform {
  String get humanName {
    switch (this) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      // TargetPlatform.ohos only exists in the flutter-ohos fork; a default
      // case keeps this file compilable against the stock SDK as well.
      // ignore: unreachable_switch_default
      default:
        return 'HarmonyOS';
    }
  }
}
