import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import 'llm/prompt_builder.dart';
import '../models/user_profile.dart';
import '../models/closet_item.dart';

enum LlmStatus { unloaded, loading, ready, error }

class LlmService {
  static final LlmService instance = LlmService._();
  LlmService._();

  LlmStatus _status = LlmStatus.unloaded;
  LlmStatus get status => _status;

  String? _modelPath;
  String? _lastError;
  String? get lastError => _lastError;

  UserProfile? _cachedProfile;
  String? _cachedSeason;
  List<ClosetItem> _cachedWardrobe = [];

  static const String _modelFilename = 'Phi-4-mini-instruct-q4_k_m.gguf';
  static const String _modelDownloadUrl =
      'https://huggingface.co/microsoft/Phi-4-mini-instruct-gguf/resolve/main/'
      'Phi-4-mini-instruct-q4_k_m.gguf';

  /// Resolves the expected path for the model file on disk.
  Future<String> get modelPath async {
    if (_modelPath != null) return _modelPath!;
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/$_modelFilename');
    _modelPath = modelFile.path;
    return _modelPath!;
  }

  bool get isModelDownloaded {
    if (_modelPath == null) return false;
    return File(_modelPath!).existsSync();
  }

  Future<int> get modelFileSize async {
    final path = await modelPath;
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  String get suggestedModel => _modelFilename;

  Future<void> refreshContext() async {
    try {
      _cachedProfile = await ProfileService().getProfile();
      final history = await DatabaseHelper.instance.fetchAllHistory();
      if (history.isNotEmpty) {
        _cachedSeason = history.first.recommendation.detectedCategory;
      }
      _cachedWardrobe = await DatabaseHelper.instance.getAllClosetItems();
    } catch (e) {
      debugPrint('LlmService: failed to refresh context: $e');
    }
  }

  String _buildSystemPrompt() {
    final builder = PromptBuilder(
      profile: _cachedProfile ?? UserProfile.defaultProfile(),
      skinToneSeason: _cachedSeason,
      wardrobe: _cachedWardrobe,
    );
    return builder.buildSystemPrompt();
  }

  String buildPrompt({required String message, String? context}) {
    final system = _buildSystemPrompt();
    final buf = StringBuffer();
    buf.writeln(system);
    buf.writeln();
    buf.writeln('--- USER QUERY ---');
    if (context != null) {
      buf.writeln('Additional context: $context');
    }
    buf.writeln(message);
    return buf.toString();
  }

  Future<String> ask(String message, {String? context}) async {
    await refreshContext();
    final prompt = buildPrompt(message: message, context: context);
    return _infer(prompt);
  }

  Future<String> askOutfitExplanation({
    required String item1Name,
    required String item1Color,
    required String item1Category,
    required String item2Name,
    required String item2Color,
    required String item2Category,
    String? accessoryName,
    String? accessoryColor,
    String? season,
    String? occasion,
  }) async {
    final prompt = PromptBuilder.outfitExplanationPrompt(
      item1Name: item1Name,
      item1Color: item1Color,
      item1Category: item1Category,
      item2Name: item2Name,
      item2Color: item2Color,
      item2Category: item2Category,
      accessoryName: accessoryName,
      accessoryColor: accessoryColor,
      season: season ?? _cachedSeason,
      occasion: occasion,
    );
    return ask(prompt);
  }

  Future<String> askShoppingAdvice({
    required String itemName,
    required String itemColor,
    required String itemCategory,
    int wardrobeCount = 0,
  }) async {
    final prompt = PromptBuilder.shoppingAdvicePrompt(
      itemName: itemName,
      itemColor: itemColor,
      itemCategory: itemCategory,
      season: _cachedSeason,
      wardrobeCount:
          wardrobeCount > 0 ? wardrobeCount : _cachedWardrobe.length,
    );
    return ask(prompt);
  }

  Future<String> _infer(String prompt) async {
    if (_status == LlmStatus.loading) {
      throw Exception('Model is still loading. Please wait.');
    }
    if (!isModelDownloaded) {
      throw Exception('Model not downloaded. Please download first.');
    }
    try {
      _status = LlmStatus.loading;
      final result = await _runInference(prompt);
      _status = LlmStatus.ready;
      return result;
    } catch (e) {
      _status = LlmStatus.error;
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<String> _runInference(String prompt) async {
    final modelFile = await modelPath;
    return _llamaCppInference(modelFile, prompt);
  }

  Future<String> _llamaCppInference(String modelPath, String prompt) async {
    // -----------------------------------------------------------------------
    // Native llama.cpp inference via llama_cpp_dart FFI bindings.
    //
    // When the llama_cpp_dart package is added to pubspec.yaml, replace the
    // body of this method with something like:
    //
    //   import 'package:llama_cpp_dart/llama_cpp_dart.dart';
    //
    //   final llama = LlamaCpp();
    //   await llama.loadModel(
    //     modelPath,
    //     nCtx: 8192,                 // Phi-4-mini supports up to 128K
    //     nGpuLayers: 1,              // enable Metal/CUDA offloading
    //   );
    //   final output = await llama.infer(
    //     prompt,
    //     maxTokens: 256,
    //     temperature: 0.7,
    //     topP: 0.9,
    //   );
    //   await llama.unloadModel();
    //   return output;
    //
    // -----------------------------------------------------------------------

    throw UnimplementedError(
      'llama.cpp native inference is not yet wired.\n\n'
      'To enable:\n'
      '  1. Add llama_cpp_dart to pubspec.yaml\n'
      '  2. Place a GGUF model at: $modelPath\n'
      '  3. Replace `_llamaCppInference` body in\n'
      '     lib/services/llm_service.dart\n\n'
      'Until then the Style Coach runs in simulation mode.',
    );
  }

  Future<void> downloadModelFuture({
    void Function(double progress)? onProgress,
  }) async {
    final path = await modelPath;
    final file = File(path);
    if (await file.exists()) {
      debugPrint('Model already exists at $path');
      _status = LlmStatus.ready;
      return;
    }
    _status = LlmStatus.loading;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_modelDownloadUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      _status = LlmStatus.ready;
      debugPrint('Model downloaded to $path');
    } catch (e) {
      _status = LlmStatus.error;
      _lastError = e.toString();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
}
