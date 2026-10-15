// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Copies an uploaded resource into the app's private documents folder so it
/// survives cache clearing. The name is sanitised to block path traversal.
Future<String?> storeLocalCopy({required String sourcePath, required String fileName}) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final folder = Directory('${docs.path}${sep}aquaaware_resources');
    await folder.create(recursive: true);
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').replaceAll('..', '_');
    final dest = '${folder.path}$sep${DateTime.now().millisecondsSinceEpoch}_$safe';
    await File(sourcePath).copy(dest);
    return dest;
  } catch (_) {
    return null;
  }
}

Future<String?> openLocalFile(String path) async {
  try {
    if (!await File(path).exists()) return 'The file is no longer on this device.';
    final result = await OpenFilex.open(path);
    return result.type == ResultType.done ? null : 'No app on this device can open this file.';
  } catch (_) {
    return 'Could not open the file.';
  }
}

Future<void> deleteLocalCopy(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
