// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.
// Conditional export: the web build never sees dart:io or open_filex.
export 'file_store_stub.dart' if (dart.library.io) 'file_store_io.dart';
