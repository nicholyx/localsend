import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

const _methodChannel = MethodChannel('org.localsend.localsend_app/ohos_file_opener');
final _logger = Logger('OhosFileOpener');

/// Opens a file or folder with the system default app on HarmonyOS.
/// The native handler lives in `app/ohos/entry/src/main/ets/entryability/LocalsendOhosPlugin.ets`.
///
/// Returns true on success. Returns false (instead of throwing) when no app can
/// open the path, so callers can show their "cannot open" dialog.
Future<bool> openPathOhos({
  required String path,
  String? mimeType,
}) async {
  try {
    return await _methodChannel.invokeMethod<bool>(
          mimeType == null ? 'openFolder' : 'openFile',
          {
            'path': path,
            'mimeType': ?mimeType,
          },
        ) ??
        false;
  } on PlatformException catch (e) {
    _logger.warning('Could not open path on HarmonyOS: $path', e);
    return false;
  }
}
