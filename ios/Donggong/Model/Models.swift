import CoreGraphics
import Foundation

struct GalleryImage: Codable, Equatable, Sendable {
    var imageHash: String
    var url: String
    var width: Int
    var height: Int

    private enum CodingKeys: String, CodingKey {
        case imageHash = "hash"
        case url, width, height
    }

    /// Width over height, with a portrait fallback for pages the index left unsized.
    var aspectRatio: CGFloat {
        width > 0 && height > 0 ? CGFloat(width) / CGFloat(height) : 0.7
    }
}

extension GalleryImage {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash) ?? ""
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 0
    }
}

struct Gallery: Codable, Equatable, Identifiable, Sendable {
    var id: Int64
    var title: String
    var thumbnail: String
    var artists: [String]
    var groups: [String]
    var characters: [String]
    var parodys: [String]
    var type: String
    var language: String
    var tags: [String]
    var images: [GalleryImage]
    var pageCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, title, thumbnail, artists, groups, characters, parodys, type, language, tags, images, pageCount
    }
}

extension Gallery {
    // Go marshals nil slices as null and omits empty images, so every field is optional on the wire.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        guard id > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Gallery id must be positive")
        }
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail) ?? ""
        artists = try container.decodeIfPresent([String].self, forKey: .artists) ?? []
        groups = try container.decodeIfPresent([String].self, forKey: .groups) ?? []
        characters = try container.decodeIfPresent([String].self, forKey: .characters) ?? []
        parodys = try container.decodeIfPresent([String].self, forKey: .parodys) ?? []
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        images = try container.decodeIfPresent([GalleryImage].self, forKey: .images) ?? []
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
    }
}

struct GalleryListResult: Decodable, Sendable {
    var galleries: [Gallery]
    var totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case galleries, totalCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        galleries = try container.decodeIfPresent([Gallery].self, forKey: .galleries) ?? []
        totalCount = max(0, try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0)
    }
}

struct TagSuggestion: Decodable, Hashable, Sendable {
    var tag: String
    var count: Int
    var type: String

    var fullTag: String { type.isEmpty ? tag : "\(type):\(tag)" }
}

/// A search label such as `female:big_breasts` split into its namespace and value.
struct TagInfo: Hashable, Sendable {
    let kind: String
    let value: String

    init(parsing label: String) {
        if let separator = label.firstIndex(of: ":") {
            kind = String(label[..<separator])
            value = Self.normalizeValue(String(label[label.index(after: separator)...]))
        } else {
            kind = "tag"
            value = Self.normalizeValue(label)
        }
    }

    var displayLabel: String { value.replacingOccurrences(of: "_", with: " ") }

    var symbolName: String {
        switch kind {
        case "female": "f.circle"
        case "male": "m.circle"
        case "artist": "paintbrush.pointed"
        case "series", "parody": "books.vertical"
        case "character": "face.smiling"
        case "group": "person.3"
        case "language": "character.bubble"
        default: "tag"
        }
    }

    static func normalizeValue(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: "_")
    }

    static func normalizeLabel(_ label: String) -> String {
        guard let separator = label.firstIndex(of: ":") else { return normalizeValue(label) }
        let kind = label[..<separator]
        let value = String(label[label.index(after: separator)...])
        return "\(kind):\(normalizeValue(value))"
    }

    static func normalizeQuery(_ query: String) -> String {
        query.split(whereSeparator: \.isWhitespace)
            .map { normalizeLabel(String($0)) }
            .joined(separator: " ")
    }
}

extension Array {
    func chunks(of size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
    }
}

extension Array where Element == Gallery {
    /// Drops repeated ids so SwiftUI identity stays unique.
    func uniquedByID() -> [Gallery] {
        var seen = Set<Int64>()
        return filter { seen.insert($0.id).inserted }
    }
}
