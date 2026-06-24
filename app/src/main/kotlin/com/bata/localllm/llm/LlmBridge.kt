package com.bata.localllm.llm

object LlmBridge {
    init {
        System.loadLibrary("localllm")
    }

    @JvmStatic external fun loadModel(path: String, nCtx: Int): Long
    @JvmStatic external fun generate(handle: Long, prompt: String, callback: TokenCallback)
    @JvmStatic external fun stopGeneration()
    @JvmStatic external fun freeModel(handle: Long)
}

fun interface TokenCallback {
    fun onToken(token: String, done: Boolean)
}
