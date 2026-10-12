import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'capabilities.dart';

/// Read-aloud for lessons and quiz questions — useful for younger readers,
/// students with low vision or dyslexia, and anyone learning in a second
/// language.
class SpeechService extends ChangeNotifier {
  FlutterTts? _tts;
  bool _speaking = false;
  String? _currentId;

  bool get available => Caps.canSpeak;
  bool get speaking => _speaking;

  /// Identifies what is being read so the right button shows "Stop".
  String? get currentId => _currentId;

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final t = FlutterTts();
    try {
      await t.setLanguage('en-IN');
    } catch (_) {
      // Fall back to the system default voice.
    }
    t.setStartHandler(() => _set(true));
    t.setCompletionHandler(() => _set(false));
    t.setCancelHandler(() => _set(false));
    t.setErrorHandler((dynamic _) => _set(false));
    _tts = t;
    return t;
  }

  void _set(bool value) {
    _speaking = value;
    if (!value) _currentId = null;
    notifyListeners();
  }

  /// [rate] 0.3 (slow) – 0.7 (fast); 0.5 is a natural pace.
  Future<bool> speak(String text, {required String id, double rate = 0.5}) async {
    if (!available || text.trim().isEmpty) return false;
    try {
      final t = await _engine();
      await t.stop();
      await t.setSpeechRate(rate);
      _currentId = id;
      _speaking = true;
      notifyListeners();
      await t.speak(text);
      return true;
    } catch (_) {
      _set(false);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _set(false);
  }

  @override
  void dispose() {
    final t = _tts;
    if (t != null) {
      t.stop().catchError((Object _) => null);
    }
    super.dispose();
  }
}
