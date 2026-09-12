package com.example.donggong.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, "donggong.db", null, 3) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS favorites (type TEXT, value TEXT, PRIMARY KEY(type, value))")
        db.execSQL("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        db.execSQL("CREATE TABLE IF NOT EXISTS recent_viewed (id INTEGER PRIMARY KEY, timestamp INTEGER)")
        db.execSQL("CREATE TABLE IF NOT EXISTS gallery_cache (id INTEGER PRIMARY KEY, json TEXT, timestamp INTEGER)")
        db.execSQL("CREATE TABLE IF NOT EXISTS recent_searches (query TEXT PRIMARY KEY, timestamp INTEGER)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("CREATE TABLE IF NOT EXISTS gallery_cache (id INTEGER PRIMARY KEY, json TEXT, timestamp INTEGER)")
        }
        if (oldVersion < 3) {
            db.execSQL("CREATE TABLE IF NOT EXISTS recent_searches (query TEXT PRIMARY KEY, timestamp INTEGER)")
        }
    }
}

object DbManager {
    private var helper: DatabaseHelper? = null
    private val json = Json { ignoreUnknownKeys = true }

    fun init(context: Context) {
        if (helper == null) {
            helper = DatabaseHelper(context.applicationContext)
        }
    }

    private val db: SQLiteDatabase
        get() = helper?.writableDatabase ?: error("DbManager not initialized")

    // Settings
    suspend fun loadSettings(): Map<String, String> = withContext(Dispatchers.IO) {
        val result = mutableMapOf<String, String>()
        val cursor = db.query("settings", arrayOf("key", "value"), null, null, null, null, null)
        cursor.use {
            val keyIndex = cursor.getColumnIndex("key")
            val valIndex = cursor.getColumnIndex("value")
            while (cursor.moveToNext()) {
                result[cursor.getString(keyIndex)] = cursor.getString(valIndex)
            }
        }
        result
    }

    suspend fun saveSetting(key: String, value: String) = withContext(Dispatchers.IO) {
        val cv = ContentValues().apply {
            put("key", key)
            put("value", value)
        }
        db.insertWithOnConflict("settings", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    // Favorites
    suspend fun loadFavorites(): Favorites = withContext(Dispatchers.IO) {
        val galleries = mutableSetOf<Long>()
        val artists = mutableSetOf<String>()
        val groups = mutableSetOf<String>()
        val characters = mutableSetOf<String>()
        val parodys = mutableSetOf<String>()
        val languages = mutableSetOf<String>()
        val tags = mutableSetOf<String>()

        val cursor = db.query("favorites", arrayOf("type", "value"), null, null, null, null, "ROWID ASC")
        cursor.use {
            val typeCol = cursor.getColumnIndex("type")
            val valCol = cursor.getColumnIndex("value")
            while (cursor.moveToNext()) {
                val type = cursor.getString(typeCol)
                val value = cursor.getString(valCol)
                when (Favorites.canonicalType(type)) {
                    "gallery" -> value.toLongOrNull()?.let { galleries.add(it) }
                    "artist" -> artists.add(value)
                    "group" -> groups.add(value)
                    "character" -> characters.add(value)
                    "series" -> parodys.add(value)
                    "language" -> languages.add(value)
                    else -> tags.add(TagInfo.parse("$type:$value").key)
                }
            }
        }

        Favorites(
            galleries = galleries,
            artists = artists,
            groups = groups,
            characters = characters,
            parodys = parodys,
            languages = languages,
            tags = tags
        )
    }

    suspend fun addFavorite(type: String, value: String) = withContext(Dispatchers.IO) {
        val cv = ContentValues().apply {
            put("type", type)
            put("value", TagInfo.normalizeTagValue(value))
        }
        db.insertWithOnConflict("favorites", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    suspend fun removeFavorite(type: String, value: String) = withContext(Dispatchers.IO) {
        db.delete("favorites", "type = ? AND value = ?", arrayOf(type, TagInfo.normalizeTagValue(value)))
    }

    suspend fun importFavorites(newFavs: Favorites) = withContext(Dispatchers.IO) {
        db.beginTransaction()
        try {
            db.delete("favorites", null, null)
            fun insert(type: String, value: String) {
                val cv = ContentValues().apply {
                    put("type", type)
                    put("value", value)
                }
                db.insertWithOnConflict("favorites", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            }
            newFavs.galleries.forEach { insert("gallery", it.toString()) }
            newFavs.artists.forEach { insert("artist", it) }
            newFavs.groups.forEach { insert("group", it) }
            newFavs.characters.forEach { insert("character", it) }
            newFavs.parodys.forEach { insert("series", it) }
            newFavs.languages.forEach { insert("language", it) }
            newFavs.tags.forEach { tagStr ->
                val info = TagInfo.parse(tagStr)
                insert(info.type, info.value)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    // History (Recent viewed)
    suspend fun getRecentViewedIds(limit: Int = 50): List<Long> = withContext(Dispatchers.IO) {
        val list = mutableListOf<Long>()
        val cursor = db.query("recent_viewed", arrayOf("id"), null, null, null, null, "timestamp DESC", limit.toString())
        cursor.use {
            val idCol = cursor.getColumnIndex("id")
            while (cursor.moveToNext()) {
                list.add(cursor.getLong(idCol))
            }
        }
        list
    }

    suspend fun addRecentViewed(id: Long) = withContext(Dispatchers.IO) {
        val cv = ContentValues().apply {
            put("id", id)
            put("timestamp", System.currentTimeMillis())
        }
        db.insertWithOnConflict("recent_viewed", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        db.execSQL("DELETE FROM recent_viewed WHERE id NOT IN (SELECT id FROM recent_viewed ORDER BY timestamp DESC LIMIT 50)")
    }

    suspend fun removeRecentViewed(id: Long) = withContext(Dispatchers.IO) {
        db.delete("recent_viewed", "id = ?", arrayOf(id.toString()))
    }

    suspend fun clearRecentViewed() = withContext(Dispatchers.IO) {
        db.delete("recent_viewed", null, null)
    }

    // Recent searches
    suspend fun getRecentSearches(limit: Int = 20): List<String> = withContext(Dispatchers.IO) {
        val list = mutableListOf<String>()
        val cursor = db.query("recent_searches", arrayOf("query"), null, null, null, null, "timestamp DESC", limit.toString())
        cursor.use {
            val queryCol = cursor.getColumnIndex("query")
            while (cursor.moveToNext()) {
                list.add(cursor.getString(queryCol))
            }
        }
        list
    }

    suspend fun addRecentSearch(query: String) = withContext(Dispatchers.IO) {
        val cv = ContentValues().apply {
            put("query", query)
            put("timestamp", System.currentTimeMillis())
        }
        db.insertWithOnConflict("recent_searches", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        db.execSQL("DELETE FROM recent_searches WHERE query NOT IN (SELECT query FROM recent_searches ORDER BY timestamp DESC LIMIT 20)")
    }

    suspend fun removeRecentSearch(query: String) = withContext(Dispatchers.IO) {
        db.delete("recent_searches", "query = ?", arrayOf(query))
    }

    // Gallery Cache
    suspend fun cacheGallery(gallery: Gallery) = withContext(Dispatchers.IO) {
        val cv = ContentValues().apply {
            put("id", gallery.id)
            put("json", json.encodeToString(gallery))
            put("timestamp", System.currentTimeMillis())
        }
        db.insertWithOnConflict("gallery_cache", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    suspend fun getCachedGalleries(ids: List<Long>): Map<Long, Gallery> = withContext(Dispatchers.IO) {
        if (ids.isEmpty()) return@withContext emptyMap()
        val result = mutableMapOf<Long, Gallery>()
        ids.chunked(100).forEach { chunk ->
            val placeholders = chunk.joinToString(",") { "?" }
            val args = chunk.map { it.toString() }.toTypedArray()
            val cursor = db.rawQuery("SELECT id, json FROM gallery_cache WHERE id IN ($placeholders)", args)
            cursor.use {
                val idCol = cursor.getColumnIndex("id")
                val jsonCol = cursor.getColumnIndex("json")
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val jsonStr = cursor.getString(jsonCol)
                    try {
                        result[id] = json.decodeFromString<Gallery>(jsonStr)
                    } catch (_: Exception) {}
                }
            }
        }
        result
    }

    suspend fun resetAllData() = withContext(Dispatchers.IO) {
        db.delete("favorites", null, null)
        db.delete("settings", null, null)
        db.delete("recent_viewed", null, null)
        db.delete("gallery_cache", null, null)
        db.delete("recent_searches", null, null)
    }
}
