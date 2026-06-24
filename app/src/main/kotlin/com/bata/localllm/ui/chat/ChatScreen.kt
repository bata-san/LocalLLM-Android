package com.bata.localllm.ui.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledIconToggleButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bata.localllm.data.model.ChatMessage
import com.bata.localllm.data.model.Role
import com.bata.localllm.ui.theme.AssistantBubble
import com.bata.localllm.ui.theme.UserBubble
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    vm: ChatViewModel = viewModel(),
    onOpenModels: () -> Unit,
) {
    val messages by vm.messages.collectAsStateWithLifecycle()
    val streaming by vm.streamingContent.collectAsStateWithLifecycle()
    val isGenerating by vm.isGenerating.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    val listState = rememberLazyListState()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    var input by remember { mutableStateOf("") }
    var useSearch by remember { mutableStateOf(false) }

    // Scroll to bottom when new content arrives
    LaunchedEffect(messages.size, streaming) {
        val count = messages.size + if (streaming.isNotEmpty()) 1 else 0
        if (count > 0) listState.animateScrollToItem(count - 1)
    }

    LaunchedEffect(error) {
        error?.let { scope.launch { snackbar.showSnackbar(it) }; vm.dismissError() }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("LocalLLM")
                        Text(
                            vm.modelName ?: "No model loaded",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (vm.isModelLoaded)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.error,
                        )
                    }
                },
                actions = {
                    if (messages.isNotEmpty()) {
                        IconButton(onClick = vm::clearHistory) {
                            Icon(Icons.Default.Clear, "Clear history")
                        }
                    }
                    IconButton(onClick = onOpenModels) {
                        Text("⚙", style = MaterialTheme.typography.bodyLarge)
                    }
                }
            )
        },
        bottomBar = {
            ChatInput(
                value = input,
                onValueChange = { input = it },
                useSearch = useSearch,
                onToggleSearch = { useSearch = !useSearch },
                isGenerating = isGenerating,
                onSend = {
                    if (input.isNotBlank()) {
                        vm.sendMessage(input.trim(), useSearch)
                        input = ""
                    }
                },
                onStop = vm::stopGeneration,
            )
        }
    ) { padding ->
        val allMessages = buildList {
            addAll(messages)
            if (streaming.isNotEmpty()) {
                add(ChatMessage(role = Role.ASSISTANT, content = streaming, isStreaming = true))
            }
        }

        if (allMessages.isEmpty() && !vm.isModelLoaded) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("Load a GGUF model to start chatting",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                reverseLayout = false,
            ) {
                items(allMessages, key = { it.id.takeIf { id -> id != 0L } ?: it.timestamp }) { msg ->
                    MessageBubble(msg)
                }
                if (isGenerating && streaming.isEmpty()) {
                    item { TypingIndicator() }
                }
            }
        }
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    val isUser = message.role == Role.USER
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .background(
                    color = if (isUser) UserBubble else AssistantBubble,
                    shape = RoundedCornerShape(
                        topStart = 16.dp, topEnd = 16.dp,
                        bottomStart = if (isUser) 16.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 16.dp,
                    )
                )
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Column {
                Text(
                    text = message.content,
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (message.isStreaming) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(10.dp).padding(top = 4.dp),
                        strokeWidth = 1.5.dp,
                        color = Color.White.copy(alpha = 0.6f),
                    )
                }
            }
        }
    }
}

@Composable
private fun TypingIndicator() {
    Row(horizontalArrangement = Arrangement.Start) {
        Box(
            modifier = Modifier
                .background(AssistantBubble, RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(3) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(6.dp),
                        strokeWidth = 1.dp,
                        color = Color.White.copy(alpha = 0.7f),
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatInput(
    value: String,
    onValueChange: (String) -> Unit,
    useSearch: Boolean,
    onToggleSearch: () -> Unit,
    isGenerating: Boolean,
    onSend: () -> Unit,
    onStop: () -> Unit,
) {
    Surface(shadowElevation = 8.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            FilledIconToggleButton(
                checked = useSearch,
                onCheckedChange = { onToggleSearch() },
                modifier = Modifier.size(48.dp),
            ) {
                Icon(Icons.Default.Search, "Toggle web search", modifier = Modifier.size(20.dp))
            }

            Spacer(Modifier.width(4.dp))

            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text(if (useSearch) "Search + ask…" else "Message…") },
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSend() }),
                shape = RoundedCornerShape(24.dp),
            )

            Spacer(Modifier.width(4.dp))

            if (isGenerating) {
                IconButton(onClick = onStop) {
                    Icon(Icons.Default.Stop, "Stop generation",
                        tint = MaterialTheme.colorScheme.error)
                }
            } else {
                IconButton(onClick = onSend, enabled = value.isNotBlank()) {
                    Icon(Icons.Default.Send, "Send")
                }
            }
        }
    }
}
