import Foundation

/// A canonical favorite: `gallery:<id>`, `artist:<name>`, `female:<tag>` and so on.
struct FavoriteKey: Hashable, Sendable {
    let kind: String
    let value: String

    static func gallery(_ id: Int64) -> FavoriteKey {
        FavoriteKey(kind: "gallery", value: String(id))
    }

    static func tag(_ label: String) -> FavoriteKey {
        let info = TagInfo(parsing: label)
        return resolve(kind: info.kind, value: info.value)
    }

    /// Maps legacy spellings (`parody`, mixed case, `type:value` stuffed into value) onto one key.
    static func resolve(kind: String, value: String) -> FavoriteKey {
        let canonical = canonicalKind(kind)
        if canonical == "gallery" {
            return FavoriteKey(kind: "gallery", value: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if value.contains(":") {
            let parsed = TagInfo(parsing: value)
            return FavoriteKey(kind: canonicalKind(parsed.kind), value: TagInfo.normalizeValue(parsed.value))
        }
        return FavoriteKey(kind: canonical, value: TagInfo.normalizeValue(value))
    }

    static func canonicalKind(_ kind: String) -> String {
        let lowered = kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered == "parody" ? "series" : lowered
    }

    var label: String { "\(kind):\(value)" }
    var galleryID: Int64? { kind == "gallery" ? Int64(value) : nil }
}

/// Favorites in display order, newest first.
struct Favorites: Equatable, Sendable {
    private(set) var keys: [FavoriteKey]
    private var lookup: Set<FavoriteKey>

    private static let namedKinds = ["artist", "group", "character", "series", "language"]

    init(_ keys: [FavoriteKey] = []) {
        var seen = Set<FavoriteKey>()
        self.keys = keys.filter { seen.insert($0).inserted }
        lookup = seen
    }

    func contains(_ key: FavoriteKey) -> Bool { lookup.contains(key) }

    func containsGallery(_ id: Int64) -> Bool { lookup.contains(.gallery(id)) }

    func containsTag(_ label: String) -> Bool { lookup.contains(.tag(label)) }

    func inserting(_ key: FavoriteKey) -> Favorites {
        contains(key) ? self : Favorites([key] + keys)
    }

    func removing(_ key: FavoriteKey) -> Favorites {
        contains(key) ? Favorites(keys.filter { $0 != key }) : self
    }

    var galleryIDs: [Int64] { keys.compactMap(\.galleryID) }

    /// Tag-like favorites first, then artists, groups, characters, series and languages.
    var chips: [String] {
        let tagLike = keys.filter { $0.kind != "gallery" && !Self.namedKinds.contains($0.kind) }
        let named = Self.namedKinds.flatMap { kind in keys.filter { $0.kind == kind } }
        return (tagLike + named).map(\.label)
    }
}

/// Reads and writes the JSON favorites backup shared with the Android app, and reads Pupil backups.
enum FavoritesBackup {
    static let maxFileSize = 8 * 1024 * 1024

    private struct DonggongBackup: Encodable {
        var favoriteId: [Int64] = []
        var favoriteArtist: [String] = []
        var favoriteTag: [String] = []
        var favoriteLanguage: [String] = []
        var favoriteGroup: [String] = []
        var favoriteParody: [String] = []
        var favoriteCharacter: [String] = []
    }

    private static let donggongKeys: Set<String> = [
        "favoriteId", "favoriteArtist", "favoriteTag", "favoriteLanguage",
        "favoriteGroup", "favoriteParody", "favoriteCharacter",
    ]

    static func encode(_ favorites: Favorites) throws -> Data {
        var backup = DonggongBackup()
        for key in favorites.keys {
            switch key.kind {
            case "gallery":
                if let id = key.galleryID { backup.favoriteId.append(id) }
            case "artist": backup.favoriteArtist.append(key.value)
            case "group": backup.favoriteGroup.append(key.value)
            case "character": backup.favoriteCharacter.append(key.value)
            case "series": backup.favoriteParody.append(key.value)
            case "language": backup.favoriteLanguage.append(key.value)
            default: backup.favoriteTag.append(key.label)
            }
        }
        return try JSONEncoder().encode(backup)
    }

    /// Returns nil for an unrecognized or structurally invalid backup.
    static func decode(_ data: Data) -> [FavoriteKey]? {
        guard data.count <= maxFileSize,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if root.keys.contains(where: { donggongKeys.contains($0) }) {
            return decodeDonggong(root)
        }
        if root["favorites"] != nil || root["favorite_tags"] != nil {
            return decodePupil(root)
        }
        return nil
    }

    private static func decodeDonggong(_ root: [String: Any]) -> [FavoriteKey]? {
        func strings(_ key: String) -> [String]? {
            guard let raw = root[key] else { return [] }
            guard let array = raw as? [Any] else { return nil }
            var result: [String] = []
            for item in array {
                guard let string = item as? String else { return nil }
                result.append(string)
            }
            return result
        }

        guard let ids = galleryIDs(root["favoriteId"]),
              let artists = strings("favoriteArtist"),
              let tags = strings("favoriteTag"),
              let languages = strings("favoriteLanguage"),
              let groups = strings("favoriteGroup"),
              let parodys = strings("favoriteParody"),
              let characters = strings("favoriteCharacter")
        else { return nil }

        var keys = ids.map(FavoriteKey.gallery)
        keys += tags.map(FavoriteKey.tag)
        keys += artists.map { FavoriteKey.resolve(kind: "artist", value: $0) }
        keys += groups.map { FavoriteKey.resolve(kind: "group", value: $0) }
        keys += characters.map { FavoriteKey.resolve(kind: "character", value: $0) }
        keys += parodys.map { FavoriteKey.resolve(kind: "series", value: $0) }
        keys += languages.map { FavoriteKey.resolve(kind: "language", value: $0) }
        return keys.filter { !$0.value.isEmpty }
    }

    private static func decodePupil(_ root: [String: Any]) -> [FavoriteKey]? {
        guard let ids = galleryIDs(root["favorites"]) else { return nil }

        var keys = ids.map(FavoriteKey.gallery)
        if let raw = root["favorite_tags"] {
            guard let array = raw as? [Any] else { return nil }
            for item in array {
                guard let object = item as? [String: Any],
                      let area = object["area"] as? String,
                      let tag = object["tag"] as? String,
                      !area.trimmingCharacters(in: .whitespaces).isEmpty,
                      !tag.trimmingCharacters(in: .whitespaces).isEmpty
                else { return nil }
                let kind = FavoriteKey.canonicalKind(area)
                guard ["artist", "group", "character", "series", "language", "tag", "male", "female"].contains(kind) else {
                    return nil
                }
                keys.append(FavoriteKey(kind: kind, value: TagInfo.normalizeValue(tag)))
            }
        }
        return keys
    }

    /// Accepts integer numbers or numeric strings, the two shapes both apps have written.
    private static func galleryIDs(_ raw: Any?) -> [Int64]? {
        guard let raw else { return [] }
        guard let array = raw as? [Any] else { return nil }
        var result: [Int64] = []
        for item in array {
            let id: Int64?
            if let string = item as? String {
                id = Int64(string.trimmingCharacters(in: .whitespaces))
            } else if let number = item as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                id = Int64(exactly: number.doubleValue)
            } else {
                id = nil
            }
            guard let id, id > 0 else { return nil }
            result.append(id)
        }
        return result
    }
}
