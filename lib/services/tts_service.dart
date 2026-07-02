import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kitten_tts_flutter/kitten_tts_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'phonemizer.dart';

class TtsService {
  final KittenTtsFlutter _tts = KittenTtsFlutter();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Phonemizer _phonemizer = Phonemizer();

  bool _initialized = false;
  bool _initializing = false;
  double _downloadProgress = 0.0;
  String? _statusMessage;

  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  double get downloadProgress => _downloadProgress;
  String? get statusMessage => _statusMessage;

  final VoidCallback? onProgressChanged;

  TtsService({this.onProgressChanged});

  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _statusMessage = "Preparing voice engine...";
    onProgressChanged?.call();

    try {
      final docDir = await getApplicationDocumentsDirectory();

      final configPath = '${docDir.path}/config.json';
      final modelPath = '${docDir.path}/kitten_tts_nano_v0_8.onnx';
      final voicesPath = '${docDir.path}/voices.npz';

      await _downloadIfMissing(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/config.json?download=true",
        configPath,
        "Downloading config...",
      );

      await _downloadIfMissing(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/kitten_tts_nano_v0_8.onnx?download=true",
        modelPath,
        "Downloading voice model (25 MB)...",
      );

      await _downloadIfMissing(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/voices.npz?download=true",
        voicesPath,
        "Downloading voice styles...",
      );

      _statusMessage = "Initializing voice engine...";
      onProgressChanged?.call();

      await _tts.init(
        configPath: configPath,
        modelPath: modelPath,
        voicesPath: voicesPath,
      );

      _initialized = true;
      _statusMessage = "Voice ready";
    } catch (e) {
      _statusMessage = "Voice init failed: $e";
    } finally {
      _initializing = false;
      onProgressChanged?.call();
    }
  }

  Future<void> _downloadIfMissing(
      String url, String destPath, String label) async {
    final file = File(destPath);
    if (file.existsSync()) return;

    _statusMessage = label;
    _downloadProgress = 0.0;
    onProgressChanged?.call();

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("Download failed: ${response.statusCode}");
    }

    final contentLength = response.contentLength ?? 0;
    int downloaded = 0;
    final sink = file.openWrite();

    await response.stream.forEach((chunk) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (contentLength > 0) {
        _downloadProgress = downloaded / contentLength;
        onProgressChanged?.call();
      }
    });
    await sink.close();
    _downloadProgress = 1.0;
    onProgressChanged?.call();
  }

  Future<void> speak(String text, {String voice = "Bella"}) async {
    if (!_initialized) return;

    try {
      final phonemes = _phonemizer.toPhonemes(text);
      final wavBytes = await _tts.generateWavBytes(
        phonemizedText: phonemes,
        language: "en",
        voice: voice,
      );
      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await wavFile.writeAsBytes(wavBytes);
      await _audioPlayer.play(DeviceFileSource(wavFile.path));
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
    _tts.release();
  }
}
