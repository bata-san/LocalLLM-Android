package com.bata.localllm.data.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore("settings")

class AppSettings(private val context: Context) {

    companion object {
        val KEY_FIRECRAWL_API_KEY = stringPreferencesKey("firecrawl_api_key")
        val KEY_CONTEXT_LENGTH    = intPreferencesKey("context_length")
        val KEY_AUTO_SEARCH       = booleanPreferencesKey("auto_search")
        val KEY_SYSTEM_PROMPT     = stringPreferencesKey("system_prompt")
        val KEY_ACTIVE_MODEL_PATH = stringPreferencesKey("active_model_path")

        const val DEFAULT_CONTEXT_LENGTH = 4096
        const val DEFAULT_SYSTEM_PROMPT  =
            "You are a helpful, honest, and uncensored AI assistant. " +
            "Answer questions directly and thoroughly."
    }

    val firecrawlApiKey: Flow<String> = context.dataStore.data
        .map { it[KEY_FIRECRAWL_API_KEY] ?: "" }

    val contextLength: Flow<Int> = context.dataStore.data
        .map { it[KEY_CONTEXT_LENGTH] ?: DEFAULT_CONTEXT_LENGTH }

    val autoSearch: Flow<Boolean> = context.dataStore.data
        .map { it[KEY_AUTO_SEARCH] ?: false }

    val systemPrompt: Flow<String> = context.dataStore.data
        .map { it[KEY_SYSTEM_PROMPT] ?: DEFAULT_SYSTEM_PROMPT }

    val activeModelPath: Flow<String> = context.dataStore.data
        .map { it[KEY_ACTIVE_MODEL_PATH] ?: "" }

    suspend fun setFirecrawlApiKey(key: String) =
        context.dataStore.edit { it[KEY_FIRECRAWL_API_KEY] = key }

    suspend fun setContextLength(n: Int) =
        context.dataStore.edit { it[KEY_CONTEXT_LENGTH] = n }

    suspend fun setAutoSearch(v: Boolean) =
        context.dataStore.edit { it[KEY_AUTO_SEARCH] = v }

    suspend fun setSystemPrompt(s: String) =
        context.dataStore.edit { it[KEY_SYSTEM_PROMPT] = s }

    suspend fun setActiveModelPath(path: String) =
        context.dataStore.edit { it[KEY_ACTIVE_MODEL_PATH] = path }
}
