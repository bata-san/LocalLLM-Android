package com.bata.localllm.search

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class FirecrawlClient(private var apiKey: String) {

    private val json = Json { ignoreUnknownKeys = true }
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    fun updateApiKey(key: String) {
        apiKey = key
    }

    suspend fun search(query: String, limit: Int = 5): List<SearchResult> =
        withContext(Dispatchers.IO) {
            val body = json.encodeToString(FirecrawlSearchRequest(query, limit))
            val request = Request.Builder()
                .url("https://api.firecrawl.dev/v2/search")
                .post(body.toRequestBody("application/json".toMediaType()))
                .header("Authorization", "Bearer $apiKey")
                .header("Content-Type", "application/json")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext emptyList()
                val resp = json.decodeFromString<FirecrawlSearchResponse>(
                    response.body?.string() ?: return@withContext emptyList()
                )
                resp.data?.web?.map { it.toSearchResult() } ?: emptyList()
            }
        }

    private fun WebResult.toSearchResult() = SearchResult(
        url = url,
        title = title,
        snippet = description,
        markdown = markdown,
    )
}

fun buildSearchContext(results: List<SearchResult>): String {
    if (results.isEmpty()) return ""
    return buildString {
        appendLine("## Web Search Results\n")
        results.forEachIndexed { i, r ->
            appendLine("### [${i + 1}] ${r.title}")
            appendLine("URL: ${r.url}")
            if (r.markdown.isNotBlank()) {
                appendLine(r.markdown.take(800))
            } else if (r.snippet.isNotBlank()) {
                appendLine(r.snippet)
            }
            appendLine()
        }
        appendLine("---\nAnswer based on the above search results:\n")
    }
}
