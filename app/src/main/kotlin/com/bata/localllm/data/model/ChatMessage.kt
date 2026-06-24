package com.bata.localllm.data.model

enum class Role { USER, ASSISTANT, SYSTEM }

data class ChatMessage(
    val id: Long = 0,
    val role: Role,
    val content: String,
    val isStreaming: Boolean = false,
    val timestamp: Long = System.currentTimeMillis(),
)
