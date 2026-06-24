package com.bata.localllm

import android.app.Application
import com.bata.localllm.data.datastore.AppSettings
import com.bata.localllm.data.db.AppDatabase
import com.bata.localllm.llm.LlmManager
import com.bata.localllm.search.FirecrawlClient

class LocalLLMApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}

class AppContainer(app: Application) {
    val settings     = AppSettings(app)
    val db           = AppDatabase.getInstance(app)
    val llm          = LlmManager(app)
    val firecrawl    = FirecrawlClient("")
}
