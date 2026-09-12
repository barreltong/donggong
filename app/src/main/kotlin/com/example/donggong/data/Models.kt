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
        val canonical = canonicalType(type)
        val normalized = TagInfo.normalizeTagValue(value)
        return when (canonical) {
            "gallery" -> galleries.contains(value.toLongOrNull() ?: 0L)
            "artist" -> artists.contains(normalized)
            "group" -> groups.contains(normalized)
            "character" -> characters.contains(normalized)
            "series" -> parodys.contains(normalized)
            "language" -> languages.contains(normalized)
            else -> if (isTagType(canonical)) tags.contains(TagInfo.parse("$canonical:$value").key) else false
        }
    }

    fun toggle(type: String, value: String): Favorites {
        val canonical = canonicalType(type)
        val normalized = TagInfo.normalizeTagValue(value)
        return if (isFavorite(type, value)) {
            when (canonical) {
                "gallery" -> copy(galleries = galleries - (value.toLongOrNull() ?: 0L))
                "artist" -> copy(artists = artists - normalized)
                "group" -> copy(groups = groups - normalized)
                "character" -> copy(characters = characters - normalized)
                "series" -> copy(parodys = parodys - normalized)
                "language" -> copy(languages = languages - normalized)
                else -> if (isTagType(canonical)) copy(tags = tags - TagInfo.parse("$canonical:$value").key) else this
            }
        } else {
            when (canonical) {
                "gallery" -> copy(galleries = galleries + (value.toLongOrNull() ?: 0L))
                "artist" -> copy(artists = artists + normalized)
                "group" -> copy(groups = groups + normalized)
                "character" -> copy(characters = characters + normalized)
                "series" -> copy(parodys = parodys + normalized)
                "language" -> copy(languages = languages + normalized)
                else -> if (isTagType(canonical)) copy(tags = tags + TagInfo.parse("$canonical:$value").key) else this
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
        fun canonicalType(type: String): String = if (type == "parody") "series" else type
        fun isTagType(type: String): Boolean = when (canonicalType(type)) {
            "tag", "male", "female" -> true
            else -> false
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
