package com.bata.localllm.search

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FirecrawlSearchRequest(
    val query: String,
    val limit: Int = 5,
    @SerialName("scrapeOptions") val scrapeOptions: ScrapeOptions = ScrapeOptions(),
)

@Serializable
data class ScrapeOptions(
    val formats: List<String> = listOf("markdown"),
)

@Serializable
data class FirecrawlSearchResponse(
    val success: Boolean,
    val data: ResponseData? = null,
)

@Serializable
data class ResponseData(
    val web: List<WebResult> = emptyList(),
)

@Serializable
data class WebResult(
    val url: String = "",
    val title: String = "",
    val description: String = "",
    val markdown: String = "",
)

data class SearchResult(
    val url: String,
    val title: String,
    val snippet: String,
    val markdown: String,
)
