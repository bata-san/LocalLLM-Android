package com.bata.localllm.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.bata.localllm.data.model.ChatMessage
import com.bata.localllm.data.model.Role

@Entity(tableName = "messages")
data class MessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val role: String,
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
) {
    fun toChatMessage() = ChatMessage(
        id = id,
        role = Role.valueOf(role),
        content = content,
        timestamp = timestamp,
    )
}

fun ChatMessage.toEntity() = MessageEntity(
    id = id,
    role = role.name,
    content = content,
    timestamp = timestamp,
)
