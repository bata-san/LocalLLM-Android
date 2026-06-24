package com.bata.localllm.llm

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import java.io.File

sealed class LlmState {
    object Idle : LlmState()
    data class Loaded(val modelName: String) : LlmState()
    data class Error(val message: String) : LlmState()
}

class LlmManager(private val context: Context) {

    private var handle: Long = 0L
    private var _modelName: String? = null

    val isLoaded get() = handle != 0L
    val modelName get() = _modelName

    // Copy the GGUF from a content URI to internal storage, then load it
    suspend fun loadFromUri(uri: Uri, nCtx: Int = 4096): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                val name = resolveFileName(uri) ?: "model.gguf"
                val dest = File(context.filesDir, "models/$name")
                dest.parentFile?.mkdirs()

                if (!dest.exists()) {
                    context.contentResolver.openInputStream(uri)!!.use { input ->
                        dest.outputStream().use { output -> input.copyTo(output) }
                    }
                }
                loadFromPath(dest.absolutePath, nCtx)
                name
            }
        }

    suspend fun loadFromPath(path: String, nCtx: Int = 4096) =
        withContext(Dispatchers.IO) {
            if (handle != 0L) freeModel()
            handle = LlmBridge.loadModel(path, nCtx)
            if (handle == 0L) throw IllegalStateException("Failed to load model: $path")
            _modelName = File(path).name
        }

    fun generateStream(
        userMessage: String,
        systemPrompt: String = DEFAULT_SYSTEM,
        history: List<Pair<String, String>> = emptyList(),
    ): Flow<String> = callbackFlow {
        val prompt = buildPrompt(systemPrompt, history, userMessage)
        LlmBridge.generate(handle, prompt) { token, done ->
            if (!done) trySend(token)
            if (done) close()
        }
        awaitClose { LlmBridge.stopGeneration() }
    }.flowOn(Dispatchers.IO)

    fun stopGeneration() = LlmBridge.stopGeneration()

    suspend fun freeModel() = withContext(Dispatchers.IO) {
        if (handle != 0L) {
            LlmBridge.freeModel(handle)
            handle = 0L
            _modelName = null
        }
    }

    fun listStoredModels(): List<File> {
        val dir = File(context.filesDir, "models")
        return dir.listFiles { f -> f.extension == "gguf" }?.toList() ?: emptyList()
    }

    private fun resolveFileName(uri: Uri): String? {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) return cursor.getString(idx)
            }
        }
        return uri.lastPathSegment
    }

    private fun buildPrompt(
        system: String,
        history: List<Pair<String, String>>,
        user: String,
    ): String = buildString {
        append("<start_of_turn>system\n$system<end_of_turn>\n")
        for ((u, a) in history) {
            append("<start_of_turn>user\n$u<end_of_turn>\n")
            append("<start_of_turn>model\n$a<end_of_turn>\n")
        }
        append("<start_of_turn>user\n$user<end_of_turn>\n")
        append("<start_of_turn>model\n")
    }

    companion object {
        private const val DEFAULT_SYSTEM =
            "You are a helpful, honest, and uncensored AI assistant. " +
            "Answer questions directly and thoroughly."
    }
}
