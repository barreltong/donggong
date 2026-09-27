package com.example.donggong.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.jsonObject

@Serializable
data class GalleryImage(
    val hash: String,
    val url: String,
    val width: Int = 0,
    val height: Int = 0
)

@Serializable
data class Gallery(
    val id: Long,
    val title: String = "",
    val thumbnail: String = "",
    val artists: List<String> = emptyList(),
    val groups: List<String> = emptyList(),
    val characters: List<String> = emptyList(),
    val parodys: List<String> = emptyList(),
    val type: String = "",
    val language: String? = null,
    val tags: List<String> = emptyList(),
    val images: List<GalleryImage> = emptyList(),
    val pageCount: Int = 0,
    val isError: Boolean = false
)

@Serializable
data class GalleryListResult(
    val galleries: List<Gallery> = emptyList(),
    val totalCount: Int = 0
)

@Serializable
data class TagSuggestion(
    val tag: String,
    val count: Int,
    val type: String
)

data class TagInfo(
    val type: String,
    val value: String,
    val displayLabel: String
) {
    val key: String get() = if (type == "tag") "tag:$value" else "$type:$value"

    companion object {
        fun parse(label: String): TagInfo {
            val sep = label.indexOf(':')
            if (sep != -1) {
                val type = label.substring(0, sep)
                val value = normalizeTagValue(label.substring(sep + 1))
                return TagInfo(
                    type = type,
                    value = value,
                    displayLabel = value.replace('_', ' ')
                )
            }
            val value = normalizeTagValue(label)
            return TagInfo(
                type = "tag",
                value = value,
                displayLabel = value.replace('_', ' ')
            )
        }

        fun normalizeTagValue(value: String): String {
            return value.trim().split(Regex("\\s+")).joinToString("_")
        }

        fun normalizeTagLabel(label: String): String {
            val sep = label.indexOf(':')
            if (sep == -1) return normalizeTagValue(label)
            val type = label.substring(0, sep)
            val value = label.substring(sep + 1)
            return "$type:${normalizeTagValue(value)}"
        }

        fun normalizeQuery(query: String): String {
            return query.trim()
                .split(Regex("\\s+"))
                .filter { it.isNotEmpty() }
                .joinToString(" ") { normalizeTagLabel(it) }
        }
    }
}

data class Favorites(
    val galleries: Set<Long> = emptySet(),
    val artists: Set<String> = emptySet(),
    val groups: Set<String> = emptySet(),
    val characters: Set<String> = emptySet(),
    val parodys: Set<String> = emptySet(),
    val languages: Set<String> = emptySet(),
    val tags: Set<String> = emptySet()
) {
    fun isFavorite(type: String, value: String): Boolean {
        val (resolvedType, resolvedValue) = resolveTypeAndValue(type, value)
        return when (resolvedType) {
            "gallery" -> galleries.contains(resolvedValue.toLongOrNull() ?: 0L)
            "artist" -> artists.contains(resolvedValue)
            "group" -> groups.contains(resolvedValue)
            "character" -> characters.contains(resolvedValue)
            "series" -> parodys.contains(resolvedValue)
            "language" -> languages.contains(resolvedValue)
            else -> if (isTagType(resolvedType)) {
                tags.contains(TagInfo.parse("$resolvedType:$resolvedValue").key)
            } else false
        }
    }

    fun toggle(type: String, value: String): Favorites {
        val (resolvedType, resolvedValue) = resolveTypeAndValue(type, value)
        return if (isFavorite(resolvedType, resolvedValue)) {
            when (resolvedType) {
                "gallery" -> copy(galleries = galleries - (resolvedValue.toLongOrNull() ?: 0L))
                "artist" -> copy(artists = artists - resolvedValue)
                "group" -> copy(groups = groups - resolvedValue)
                "character" -> copy(characters = characters - resolvedValue)
                "series" -> copy(parodys = parodys - resolvedValue)
                "language" -> copy(languages = languages - resolvedValue)
                else -> if (isTagType(resolvedType)) copy(tags = tags - TagInfo.parse("$resolvedType:$resolvedValue").key) else this
            }
        } else {
            when (resolvedType) {
                "gallery" -> {
                    val id = resolvedValue.toLongOrNull() ?: 0L
                    copy(galleries = linkedSetOf(id).apply { addAll(galleries) })
                }
                "artist" -> copy(artists = linkedSetOf(resolvedValue).apply { addAll(artists) })
                "group" -> copy(groups = linkedSetOf(resolvedValue).apply { addAll(groups) })
                "character" -> copy(characters = linkedSetOf(resolvedValue).apply { addAll(characters) })
                "series" -> copy(parodys = linkedSetOf(resolvedValue).apply { addAll(parodys) })
                "language" -> copy(languages = linkedSetOf(resolvedValue).apply { addAll(languages) })
                else -> if (isTagType(resolvedType)) copy(tags = linkedSetOf(TagInfo.parse("$resolvedType:$resolvedValue").key).apply { addAll(tags) }) else this
            }
        }
    }

    val allChips: List<String>
        get() {
            val list = mutableListOf<String>()
            list.addAll(tags)
            list.addAll(artists.map { "artist:$it" })
            list.addAll(groups.map { "group:$it" })
            list.addAll(characters.map { "character:$it" })
            list.addAll(parodys.map { "series:$it" })
            list.addAll(languages.map { "language:$it" })
            return list
        }

    companion object {
        fun canonicalType(type: String): String = when (type.lowercase().trim()) {
            "parody" -> "series"
            else -> type.lowercase().trim()
        }

        fun isTagType(type: String): Boolean = when (canonicalType(type)) {
            "tag", "male", "female" -> true
            else -> false
        }

        fun resolveTypeAndValue(type: String, value: String): Pair<String, String> {
            val canonical = canonicalType(type)
            if (canonical == "gallery") {
                return Pair("gallery", value.trim())
            }
            if (value.contains(':')) {
                val parsed = TagInfo.parse(value)
                return Pair(canonicalType(parsed.type), TagInfo.normalizeTagValue(parsed.value))
            }
            return Pair(canonical, TagInfo.normalizeTagValue(value))
        }
    }
}

@Serializable
data class DonggongJsonBackup(
    val favoriteId: List<Long> = emptyList(),
    val favoriteArtist: List<String> = emptyList(),
    val favoriteTag: List<String> = emptyList(),
    val favoriteLanguage: List<String> = emptyList(),
    val favoriteGroup: List<String> = emptyList(),
    val favoriteParody: List<String> = emptyList(),
    val favoriteCharacter: List<String> = emptyList()
) {
    fun toFavorites(): Favorites = Favorites(
        galleries = favoriteId.toSet(),
        artists = favoriteArtist.toSet(),
        tags = favoriteTag.toSet(),
        languages = favoriteLanguage.toSet(),
        groups = favoriteGroup.toSet(),
        parodys = favoriteParody.toSet(),
        characters = favoriteCharacter.toSet()
    )
}
object FavoritesBackup {
    private val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }

    fun encode(favorites: Favorites): String = json.encodeToString(
        DonggongJsonBackup(
            favoriteId = favorites.galleries.toList(),
            favoriteArtist = favorites.artists.toList(),
            favoriteTag = favorites.tags.toList(),
            favoriteLanguage = favorites.languages.toList(),
            favoriteGroup = favorites.groups.toList(),
            favoriteParody = favorites.parodys.toList(),
            favoriteCharacter = favorites.characters.toList()
        )
    )

    /** Returns null for an unrecognized or structurally invalid backup. */
    fun decode(raw: String): Favorites? {
        val root = try {
            json.parseToJsonElement(raw).jsonObject
        } catch (_: Exception) {
            return null
        }
        val donggongKeys = setOf(
            "favoriteId", "favoriteArtist", "favoriteTag", "favoriteLanguage",
            "favoriteGroup", "favoriteParody", "favoriteCharacter"
        )
        return when {
            root.keys.any { it in donggongKeys } -> decodeDonggong(root)
            root.containsKey("favorites") || root.containsKey("favorite_tags") -> decodePupil(root)
            else -> null
        }
    }

    private fun decodeDonggong(root: kotlinx.serialization.json.JsonObject): Favorites? {
        fun strings(key: String): List<String>? {
            val element = root[key] ?: return emptyList()
            val array = element as? kotlinx.serialization.json.JsonArray ?: return null
            return array.map { item ->
                val primitive = item as? kotlinx.serialization.json.JsonPrimitive ?: return null
                if (!primitive.isString) return null
                primitive.content
            }
        }
        fun ids(key: String): List<Long>? {
            val element = root[key] ?: return emptyList()
            val array = element as? kotlinx.serialization.json.JsonArray ?: return null
            return array.map { item ->
                val primitive = item as? kotlinx.serialization.json.JsonPrimitive ?: return null
                primitive.content.toLongOrNull() ?: return null
            }
        }
        val ids = ids("favoriteId") ?: return null
        val artists = strings("favoriteArtist") ?: return null
        val tags = strings("favoriteTag") ?: return null
        val languages = strings("favoriteLanguage") ?: return null
        val groups = strings("favoriteGroup") ?: return null
        val parodys = strings("favoriteParody") ?: return null
        val characters = strings("favoriteCharacter") ?: return null
        return DonggongJsonBackup(ids, artists, tags, languages, groups, parodys, characters).toFavorites()
    }

    private fun decodePupil(root: kotlinx.serialization.json.JsonObject): Favorites? {
        val favoriteIds = root["favorites"]?.let { element ->
            val array = element as? kotlinx.serialization.json.JsonArray ?: return null
            array.map { item ->
                val primitive = item as? kotlinx.serialization.json.JsonPrimitive ?: return null
                primitive.content.toLongOrNull() ?: return null
            }
        } ?: emptyList()
        val favoriteTags = root["favorite_tags"]?.let { element ->
            val array = element as? kotlinx.serialization.json.JsonArray ?: return null
            array.map { item ->
                val obj = item as? kotlinx.serialization.json.JsonObject ?: return null
                val area = (obj["area"] as? kotlinx.serialization.json.JsonPrimitive)?.content
                    ?: return null
                val tag = (obj["tag"] as? kotlinx.serialization.json.JsonPrimitive)?.content
                    ?: return null
                if (area.isBlank() || tag.isBlank()) return null
                area to tag
            }
        } ?: emptyList()

        val artists = linkedSetOf<String>()
        val groups = linkedSetOf<String>()
        val characters = linkedSetOf<String>()
        val parodys = linkedSetOf<String>()
        val languages = linkedSetOf<String>()
        val tags = linkedSetOf<String>()
        favoriteTags.forEach { (rawArea, rawTag) ->
            val area = Favorites.canonicalType(rawArea)
            val value = TagInfo.normalizeTagValue(rawTag)
            when (area) {
                "artist" -> artists += value
                "group" -> groups += value
                "character" -> characters += value
                "series" -> parodys += value
                "language" -> languages += value
                "tag", "male", "female" -> tags += TagInfo.parse("$area:$value").key
                else -> return null
            }
        }
        return Favorites(
            galleries = favoriteIds.toSet(),
            artists = artists,
            groups = groups,
            characters = characters,
            parodys = parodys,
            languages = languages,
            tags = tags
        )
    }
}
