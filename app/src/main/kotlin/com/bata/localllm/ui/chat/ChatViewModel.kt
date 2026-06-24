package com.bata.localllm.ui.chat

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.bata.localllm.LocalLLMApp
import com.bata.localllm.data.db.toEntity
import com.bata.localllm.data.model.ChatMessage
import com.bata.localllm.data.model.Role
import com.bata.localllm.search.buildSearchContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ChatViewModel(app: Application) : AndroidViewModel(app) {

    private val container = (app as LocalLLMApp).container

    val messages: StateFlow<List<ChatMessage>> =
        container.db.messageDao().observeAll()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
            .let {
                // map entity list → domain model list
                MutableStateFlow<List<ChatMessage>>(emptyList()).also { state ->
                    viewModelScope.launch {
                        container.db.messageDao().observeAll().collect { entities ->
                            state.value = entities.map { e -> e.toChatMessage() }
                        }
                    }
                }
            }

    private val _streamingContent = MutableStateFlow("")
    val streamingContent: StateFlow<String> = _streamingContent.asStateFlow()

    private val _isGenerating = MutableStateFlow(false)
    val isGenerating: StateFlow<Boolean> = _isGenerating.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    val isModelLoaded get() = container.llm.isLoaded
    val modelName get() = container.llm.modelName

    fun sendMessage(text: String, useSearch: Boolean) {
        if (text.isBlank() || _isGenerating.value) return

        viewModelScope.launch {
            _isGenerating.value = true
            _error.value = null
            _streamingContent.value = ""

            val userMsg = ChatMessage(role = Role.USER, content = text)
            container.db.messageDao().insert(userMsg.toEntity())

            try {
                val context = if (useSearch) fetchSearchContext(text) else ""
                val fullPrompt = if (context.isNotBlank()) "$context$text" else text

                val history = container.db.messageDao()
                    .recentMessages(10)
                    .reversed()
                    .filter { it.role != Role.SYSTEM.name }
                    .map { it.role to it.content }
                    .chunked(2)
                    .filter { it.size == 2 }
                    .map { it[0].second to it[1].second }

                val systemPrompt = container.settings.systemPrompt.first()

                container.llm.generateStream(fullPrompt, systemPrompt, history)
                    .collect { token -> _streamingContent.update { it + token } }

                val assistantMsg = ChatMessage(
                    role = Role.ASSISTANT,
                    content = _streamingContent.value,
                )
                container.db.messageDao().insert(assistantMsg.toEntity())
            } catch (e: Exception) {
                _error.value = e.message ?: "Generation failed"
            } finally {
                _streamingContent.value = ""
                _isGenerating.value = false
            }
        }
    }

    fun stopGeneration() {
        container.llm.stopGeneration()
    }

    fun clearHistory() {
        viewModelScope.launch { container.db.messageDao().clearAll() }
    }

    fun dismissError() { _error.value = null }

    private suspend fun fetchSearchContext(query: String): String {
        val apiKey = container.settings.firecrawlApiKey.first()
        if (apiKey.isBlank()) return ""
        return try {
            container.firecrawl.updateApiKey(apiKey)
            val results = container.firecrawl.search(query)
            buildSearchContext(results)
        } catch (_: Exception) {
            ""
        }
    }
}
