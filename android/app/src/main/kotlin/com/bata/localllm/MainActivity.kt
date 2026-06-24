package com.bata.localllm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val llmHandler = LlmChannelHandler()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        llmHandler.setup(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        llmHandler.dispose()
        super.onDestroy()
    }
}
