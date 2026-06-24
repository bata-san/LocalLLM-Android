package com.bata.localllm.ui.models

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.bata.localllm.LocalLLMApp
import com.bata.localllm.data.model.GgufModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

sealed class ModelLoadState {
    object Idle : ModelLoadState()
    object Loading : ModelLoadState()
    data class Success(val name: String) : ModelLoadState()
    data class Error(val message: String) : ModelLoadState()
}

class ModelsViewModel(app: Application) : AndroidViewModel(app) {

    private val container = (app as LocalLLMApp).container

    private val _models = MutableStateFlow<List<GgufModel>>(emptyList())
    val models: StateFlow<List<GgufModel>> = _models.asStateFlow()

    private val _loadState = MutableStateFlow<ModelLoadState>(ModelLoadState.Idle)
    val loadState: StateFlow<ModelLoadState> = _loadState.asStateFlow()

    val activeModelName get() = container.llm.modelName

    init { refreshModels() }

    fun refreshModels() {
        _models.value = container.llm.listStoredModels()
            .map { GgufModel(it) }
            .sortedByDescending { it.file.lastModified() }
    }

    fun loadFromUri(uri: Uri) {
        viewModelScope.launch {
            _loadState.value = ModelLoadState.Loading
            val ctx = container.settings.contextLength.first()
            container.llm.loadFromUri(uri, ctx)
                .onSuccess { name ->
                    container.settings.setActiveModelPath(
                        container.llm.listStoredModels()
                            .first { it.name == name }.absolutePath
                    )
                    _loadState.value = ModelLoadState.Success(name)
                    refreshModels()
                }
                .onFailure { e ->
                    _loadState.value = ModelLoadState.Error(e.message ?: "Load failed")
                }
        }
    }

    fun loadStoredModel(model: GgufModel) {
        viewModelScope.launch {
            _loadState.value = ModelLoadState.Loading
            runCatching {
                val ctx = container.settings.contextLength.first()
                container.llm.loadFromPath(model.file.absolutePath, ctx)
            }.onSuccess {
                _loadState.value = ModelLoadState.Success(model.name)
            }.onFailure { e ->
                _loadState.value = ModelLoadState.Error(e.message ?: "Load failed")
            }
        }
    }

    fun deleteModel(model: GgufModel) {
        model.file.delete()
        if (container.llm.modelName == model.name) {
            viewModelScope.launch { container.llm.freeModel() }
        }
        refreshModels()
    }

    fun dismissState() { _loadState.value = ModelLoadState.Idle }
}
