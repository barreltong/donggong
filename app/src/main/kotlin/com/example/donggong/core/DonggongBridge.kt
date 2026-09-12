package com.example.donggong.core

import com.example.donggong.data.Gallery
import com.example.donggong.data.GalleryListResult
import com.example.donggong.data.TagSuggestion
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

object DonggongBridge {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    init {
        core.Core.init()
    }

    suspend fun getList(page: Int, lang: String): GalleryListResult = withContext(Dispatchers.IO) {
        try {
            val jsonStr = core.Core.getListJson(page.toLong(), lang)
            json.decodeFromString<GalleryListResult>(jsonStr)
        } catch (e: Exception) {
            GalleryListResult()
        }
    }

    suspend fun search(query: String, page: Int, defaultLang: String): GalleryListResult = withContext(Dispatchers.IO) {
        try {
            val jsonStr = core.Core.searchJson(query, page.toLong(), defaultLang)
            json.decodeFromString<GalleryListResult>(jsonStr)
        } catch (e: Exception) {
            GalleryListResult()
        }
    }

    suspend fun getDetail(id: Long): Gallery = withContext(Dispatchers.IO) {
        try {
            val jsonStr = core.Core.getDetailJson(id)
            json.decodeFromString<Gallery>(jsonStr)
        } catch (e: Exception) {
            Gallery(id = id, title = "Error loading gallery", isError = true)
        }
    }

    suspend fun getReaderData(id: Long): Gallery = withContext(Dispatchers.IO) {
        try {
            val jsonStr = core.Core.getReaderDataJson(id)
            json.decodeFromString<Gallery>(jsonStr)
        } catch (e: Exception) {
            Gallery(id = id, title = "Error loading reader", isError = true)
        }
    }

    suspend fun getTagSuggestions(query: String): List<TagSuggestion> = withContext(Dispatchers.IO) {
        try {
            val jsonStr = core.Core.getTagSuggestionsJson(query)
            json.decodeFromString<List<TagSuggestion>>(jsonStr)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun resolveImageUrl(hash: String, forceRefresh: Boolean = false): String = withContext(Dispatchers.IO) {
        try {
            core.Core.resolveImageUrl(hash, forceRefresh)
        } catch (e: Exception) {
            ""
        }
    }

    suspend fun fetchBytes(url: String): ByteArray = withContext(Dispatchers.IO) {
        try {
            core.Core.fetchBytes(url)
        } catch (e: Exception) {
            ByteArray(0)
        }
    }
}
