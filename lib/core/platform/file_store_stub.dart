/// Web: files cannot be copied into app storage or opened by path.
Future<String?> storeLocalCopy({required String sourcePath, required String fileName}) async => null;

/// Returns null on success, otherwise a message to show.
Future<String?> openLocalFile(String path) async =>
    'Opening files is not available in the browser. Use the mobile or desktop app.';

Future<void> deleteLocalCopy(String path) async {}
