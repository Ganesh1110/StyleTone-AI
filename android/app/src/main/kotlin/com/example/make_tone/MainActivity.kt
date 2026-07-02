package com.example.make_tone

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Force-register all plugins (Camera, ML Kit, Dio, etc.)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}