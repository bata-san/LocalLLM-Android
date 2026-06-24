package com.bata.localllm

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class LlmChannelHandler {

    private var handle: Long = 0L
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setup(messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.bata.localllm/llm").setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("ARGS", "path required", null)
                    val nCtx = call.argument<Int>("nCtx") ?: 4096
                    Thread {
                        val h = LlmBridge.loadModel(path, nCtx)
                        mainHandler.post {
                            if (h != 0L) { handle = h; result.success(null) }
                            else result.error("LOAD_FAILED", "Failed to load model", null)
                        }
                    }.start()
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt") ?: return@setMethodCallHandler result.error("ARGS", "prompt required", null)
                    if (handle == 0L) return@setMethodCallHandler result.error("NO_MODEL", "No model loaded", null)
                    result.success(null)
                    generateAsync(prompt)
                }
                "stopGeneration" -> {
                    LlmBridge.stopGeneration()
                    result.success(null)
                }
                "freeModel" -> {
                    if (handle != 0L) { LlmBridge.freeModel(handle); handle = 0L }
                    result.success(null)
                }
                "isModelLoaded" -> result.success(handle != 0L)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "com.bata.localllm/llm_stream").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun generateAsync(prompt: String) {
        Thread {
            LlmBridge.generate(handle, prompt) { token, done ->
                mainHandler.post {
                    if (done) eventSink?.endOfStream()
                    else eventSink?.success(token)
                }
            }
        }.start()
    }

    fun dispose() {
        if (handle != 0L) { LlmBridge.freeModel(handle); handle = 0L }
    }
}
