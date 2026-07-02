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

  bool _initialized = false;
  bool _initializing = false;
  double _downloadProgress = 0.0;
  String? _statusMessage;

  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  double get downloadProgress => _downloadProgress;
  String? get statusMessage => _statusMessage;

  VoidCallback? onProgressChanged;

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
      debugPrint('TTS init error: $e');
    } finally {
      _initializing = false;
      onProgressChanged?.call();
    }
  }

  Future<void> _downloadIfMissing(
    String url,
    String destPath,
    String label,
  ) async {
    final file = File(destPath);
    if (await file.exists()) return;

    _statusMessage = label;
    _downloadProgress = 0.0;
    onProgressChanged?.call();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Download failed: ${response.statusCode}");
      }

      final contentLength = response.contentLength ?? 0;
      final fileSink = file.openWrite();
      int bytesDownloaded = 0;

      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        bytesDownloaded += chunk.length;
        if (contentLength > 0) {
          _downloadProgress = bytesDownloaded / contentLength;
          onProgressChanged?.call();
        }
      }

      await fileSink.close();
      _downloadProgress = 1.0;
      onProgressChanged?.call();
    } catch (e) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> speak(String text, {String voice = "Bella"}) async {
    if (!_initialized) {
      debugPrint('TTS not initialized');
      return;
    }

    try {
      final phonemizedText = Phonemizer().toPhonemes(text);
      final wavBytes = await _tts.generateWavBytes(
        phonemizedText: phonemizedText,
        language: 'en',
        voice: voice,
        speed: 1.0,
      );

      // Play directly using BytesSource (no temp file needed)
      await _audioPlayer.play(BytesSource(wavBytes));
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
