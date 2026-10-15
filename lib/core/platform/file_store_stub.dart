// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.
/// Web: files cannot be copied into app storage or opened by path.
Future<String?> storeLocalCopy({required String sourcePath, required String fileName}) async => null;

/// Returns null on success, otherwise a message to show.
Future<String?> openLocalFile(String path) async =>
    'Opening files is not available in the browser. Use the mobile or desktop app.';

Future<void> deleteLocalCopy(String path) async {}
