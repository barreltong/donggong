package com.example.donggong.data

import kotlinx.serialization.Serializable

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
)
