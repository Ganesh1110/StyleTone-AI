import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  bool _initializing = false;
  String? _statusMessage;

  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  double get downloadProgress => 1.0; // Native engine requires no downloads!
  String? get statusMessage => _statusMessage;

  VoidCallback? onProgressChanged;

  TtsService({this.onProgressChanged});

  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _statusMessage = "Preparing native voice...";
    onProgressChanged?.call();

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _initialized = true;
      _statusMessage = "Voice ready";
    } catch (e) {
      _statusMessage = "Voice init failed: $e";
      debugPrint('TTS init error: $e');
    } finally {
      _initializing = false;
      onProgressChanged?.call();
    }
  }

  Future<void> speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
