// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.
/// Rules for files educators share with their class.
///
/// The extension alone proves nothing — anyone can rename `game.exe` to
/// `worksheet.pdf`. So the first bytes of the file (its "magic number", a
/// fixed signature every real file of that type starts with) must match the
/// extension too.
abstract final class FileRules {
  static const allowed = ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'odt', 'odp', 'txt'];
  static const maxBytes = 25 * 1024 * 1024;

  /// How many leading bytes [contentMatches] needs.
  static const headLength = 512;

  static const _pdf = [0x25, 0x50, 0x44, 0x46, 0x2D]; // "%PDF-"
  static const _zip = [0x50, 0x4B, 0x03, 0x04]; // "PK.." — docx, pptx, odt, odp
  static const _ole = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]; // legacy doc, ppt

  static bool _startsWith(List<int> head, List<int> sig) {
    if (head.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (head[i] != sig[i]) return false;
    }
    return true;
  }

  /// True when [head] (the first bytes of the file) fits extension [ext].
  static bool contentMatches(String ext, List<int> head) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return _startsWith(head, _pdf);
      case 'docx':
      case 'pptx':
      case 'odt':
      case 'odp':
        return _startsWith(head, _zip);
      case 'doc':
      case 'ppt':
        return _startsWith(head, _ole);
      case 'txt':
        // Plain text never contains NUL bytes; binaries almost always do.
        return head.isNotEmpty && !head.contains(0);
      default:
        return false;
    }
  }
}
