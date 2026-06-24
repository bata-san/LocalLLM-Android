package com.bata.localllm.ui.settings

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.bata.localllm.LocalLLMApp
import com.bata.localllm.data.datastore.AppSettings
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsViewModel(app: Application) : AndroidViewModel(app) {

    private val settings = (app as LocalLLMApp).container.settings

    val firecrawlApiKey = settings.firecrawlApiKey
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), "")

    val contextLength = settings.contextLength
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000),
            AppSettings.DEFAULT_CONTEXT_LENGTH)

    val autoSearch = settings.autoSearch
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    val systemPrompt = settings.systemPrompt
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000),
            AppSettings.DEFAULT_SYSTEM_PROMPT)

    fun setApiKey(key: String) =
        viewModelScope.launch { settings.setFirecrawlApiKey(key) }

    fun setContextLength(n: Int) =
        viewModelScope.launch { settings.setContextLength(n) }

    fun setAutoSearch(v: Boolean) =
        viewModelScope.launch { settings.setAutoSearch(v) }

    fun setSystemPrompt(s: String) =
        viewModelScope.launch { settings.setSystemPrompt(s) }
}
