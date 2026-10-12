// Conditional export: the web build never sees dart:io or open_filex.
export 'file_store_stub.dart' if (dart.library.io) 'file_store_io.dart';
