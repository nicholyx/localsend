import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:path_provider/path_provider.dart' as path;

Future<String> getDefaultDestinationDirectory() async {
  // if/else instead of an exhaustive switch: the flutter-ohos fork adds
  // TargetPlatform.ohos, which breaks exhaustive switches compiled against
  // the stock SDK's enum.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return await getDownloadsDirectoryAndroid() ?? '/storage/emulated/0/Download';
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return (await path.getApplicationDocumentsDirectory()).path;
  }
  var downloadDir = await path.getDownloadsDirectory();
  if (downloadDir == null) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      downloadDir = Directory('${Platform.environment['HOMEPATH']}/Downloads');
      if (!downloadDir.existsSync()) {
        downloadDir = Directory(Platform.environment['HOMEPATH']!);
      }
    } else {
      downloadDir = Directory('${Platform.environment['HOME']}/Downloads');
      if (!downloadDir.existsSync()) {
        downloadDir = Directory(Platform.environment['HOME']!);
      }
    }
  }
  return downloadDir.path.replaceAll('\\', '/');
}

Future<String> getCacheDirectory() async {
  final dir = await path.getTemporaryDirectory();
  await dir.create(recursive: true);
  return dir.path;
}
