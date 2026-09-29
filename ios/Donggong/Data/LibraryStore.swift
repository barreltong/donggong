import Foundation
import Observation
import OSLog
import SwiftData

@Model
final class FavoriteRecord {
    #Unique<FavoriteRecord>([\.kind, \.value])

    var kind: String
    var value: String
    var addedAt: Date

    init(kind: String, value: String, addedAt: Date) {
        self.kind = kind
        self.value = value
        self.addedAt = addedAt
    }
}

@Model
final class HistoryRecord {
    @Attribute(.unique) var galleryID: Int64
    var viewedAt: Date

    init(galleryID: Int64, viewedAt: Date) {
        self.galleryID = galleryID
        self.viewedAt = viewedAt
    }
}

@Model
final class GalleryCacheRecord {
    @Attribute(.unique) var galleryID: Int64
    var payload: Data
    var cachedAt: Date

    init(galleryID: Int64, payload: Data, cachedAt: Date) {
        self.galleryID = galleryID
        self.payload = payload
        self.cachedAt = cachedAt
    }
}

@Model
final class RecentSearchRecord {
    @Attribute(.unique) var query: String
    var searchedAt: Date

    init(query: String, searchedAt: Date) {
        self.query = query
        self.searchedAt = searchedAt
    }
}

enum Persistence {
    /// Opens the on-disk store. When that fails the app still runs on an in-memory
    /// store, and `failed` tells the UI to warn that nothing will be saved.
    static func makeContainer() -> (container: ModelContainer, failed: Bool) {
        let schema = Schema([
            FavoriteRecord.self, HistoryRecord.self, GalleryCacheRecord.self, RecentSearchRecord.self,
        ])
        do {
            let onDisk = ModelConfiguration(schema: schema)
            return (try ModelContainer(for: schema, configurations: onDisk), false)
        } catch {
            Logger(subsystem: "io.github.devgaki.donggong", category: "Persistence")
                .error("Persistent store unavailable: \(error.localizedDescription)")
            let memoryOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return (try ModelContainer(for: schema, configurations: memoryOnly), true)
            } catch {
                fatalError("In-memory store unavailable: \(error)")
            }
        }
    }
}

/// Favorites, history, recent searches and the gallery metadata cache.
@MainActor
@Observable
final class LibraryStore {
    static let historyLimit = 50
    static let recentSearchLimit = 20

    private(set) var favorites = Favorites()
    /// Bumped on every history change so history screens know to reload.
    private(set) var historyRevision = 0

    private let context: ModelContext
    private let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "LibraryStore")

    init(container: ModelContainer) {
        context = container.mainContext
        context.autosaveEnabled = false
        do {
            favorites = try loadFavorites()
        } catch {
            logger.error("Could not load favorites: \(error.localizedDescription)")
        }
    }

    // MARK: Favorites

    /// Returns whether the key is a favorite after the toggle.
    @discardableResult
    func toggleFavorite(_ key: FavoriteKey, gallery: Gallery? = nil) throws -> Bool {
        let kind = key.kind
        let value = key.value
        let existing = try context.fetch(FetchDescriptor<FavoriteRecord>(
            predicate: #Predicate { $0.kind == kind && $0.value == value }
        ))
        let added = existing.isEmpty
        if added {
            context.insert(FavoriteRecord(kind: kind, value: value, addedAt: .now))
            if let gallery, key.galleryID == gallery.id {
                try upsertCache(gallery)
            }
        } else {
            existing.forEach { context.delete($0) }
        }
        try save()
        favorites = added ? favorites.inserting(key) : favorites.removing(key)
        return added
    }

    /// Replaces every favorite with `keys`, keeping their order as the display order.
    func replaceFavorites(with keys: [FavoriteKey]) throws {
        let ordered = Favorites(keys).keys
        let existing = try context.fetch(FetchDescriptor<FavoriteRecord>())
        var rowsByKey: [FavoriteKey: FavoriteRecord] = [:]
        for row in existing {
            let key = FavoriteKey(kind: row.kind, value: row.value)
            if rowsByKey[key] == nil {
                rowsByKey[key] = row
            } else {
                context.delete(row)
            }
        }

        // Updating rows in place avoids deleting and re-inserting the same unique key in one save.
        let now = Date.now
        for (index, key) in ordered.enumerated() {
            let addedAt = now.addingTimeInterval(-Double(index) / 1000)
            if let row = rowsByKey.removeValue(forKey: key) {
                row.addedAt = addedAt
            } else {
                context.insert(FavoriteRecord(kind: key.kind, value: key.value, addedAt: addedAt))
            }
        }
        rowsByKey.values.forEach { context.delete($0) }
        try save()
        favorites = Favorites(ordered)
    }

    private func loadFavorites() throws -> Favorites {
        let rows = try context.fetch(FetchDescriptor<FavoriteRecord>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        ))
        return Favorites(rows.map { FavoriteKey.resolve(kind: $0.kind, value: $0.value) })
    }

    // MARK: History

    func recordView(_ gallery: Gallery) throws {
        let id = gallery.id
        let existing = try context.fetch(FetchDescriptor<HistoryRecord>(
            predicate: #Predicate { $0.galleryID == id }
        ))
        if let row = existing.first {
            row.viewedAt = .now
        } else {
            context.insert(HistoryRecord(galleryID: id, viewedAt: .now))
        }
        try upsertCache(gallery)

        var overflow = FetchDescriptor<HistoryRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        overflow.fetchOffset = Self.historyLimit
        try context.fetch(overflow).forEach { context.delete($0) }
        try save()
        historyRevision += 1
    }

    func historyIDs() throws -> [Int64] {
        var descriptor = FetchDescriptor<HistoryRecord>(sortBy: [SortDescriptor(\.viewedAt, order: .reverse)])
        descriptor.fetchLimit = Self.historyLimit
        return try context.fetch(descriptor).map(\.galleryID)
    }

    func removeHistory(_ id: Int64) throws {
        try context.delete(model: HistoryRecord.self, where: #Predicate { $0.galleryID == id })
        try save()
        historyRevision += 1
    }

    func clearHistory() throws {
        try context.delete(model: HistoryRecord.self)
        try save()
        historyRevision += 1
    }

    // MARK: Recent searches

    func recentSearches() -> [String] {
        var descriptor = FetchDescriptor<RecentSearchRecord>(sortBy: [SortDescriptor(\.searchedAt, order: .reverse)])
        descriptor.fetchLimit = Self.recentSearchLimit
        do {
            return try context.fetch(descriptor).map(\.query)
        } catch {
            logger.error("Could not load recent searches: \(error.localizedDescription)")
            return []
        }
    }

    func addRecentSearch(_ query: String) throws {
        let existing = try context.fetch(FetchDescriptor<RecentSearchRecord>(
            predicate: #Predicate { $0.query == query }
        ))
        if let row = existing.first {
            row.searchedAt = .now
        } else {
            context.insert(RecentSearchRecord(query: query, searchedAt: .now))
        }
        var overflow = FetchDescriptor<RecentSearchRecord>(sortBy: [SortDescriptor(\.searchedAt, order: .reverse)])
        overflow.fetchOffset = Self.recentSearchLimit
        try context.fetch(overflow).forEach { context.delete($0) }
        try save()
    }

    func removeRecentSearch(_ query: String) throws {
        try context.delete(model: RecentSearchRecord.self, where: #Predicate { $0.query == query })
        try save()
    }

    func clearRecentSearches() throws {
        try context.delete(model: RecentSearchRecord.self)
        try save()
    }

    // MARK: Gallery cache

    func cacheGallery(_ gallery: Gallery) {
        do {
            try upsertCache(gallery)
            try save()
        } catch {
            logger.error("Could not cache gallery \(gallery.id): \(error.localizedDescription)")
        }
    }

    func cachedGalleries(ids: [Int64]) -> [Int64: Gallery] {
        guard !ids.isEmpty else { return [:] }
        do {
            let rows = try context.fetch(FetchDescriptor<GalleryCacheRecord>(
                predicate: #Predicate { ids.contains($0.galleryID) }
            ))
            let decoder = JSONDecoder()
            var result: [Int64: Gallery] = [:]
            for row in rows {
                if let gallery = try? decoder.decode(Gallery.self, from: row.payload) {
                    result[row.galleryID] = gallery
                }
            }
            return result
        } catch {
            logger.error("Could not read gallery cache: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: Maintenance

    func clearCache() async throws {
        try context.delete(model: GalleryCacheRecord.self)
        try save()
        try await ImagePipeline.shared.clear()
    }

    func resetAll() async throws {
        try context.delete(model: FavoriteRecord.self)
        try context.delete(model: HistoryRecord.self)
        try context.delete(model: GalleryCacheRecord.self)
        try context.delete(model: RecentSearchRecord.self)
        try save()
        favorites = Favorites()
        historyRevision += 1
        try await ImagePipeline.shared.clear()
    }

    private func upsertCache(_ gallery: Gallery) throws {
        let id = gallery.id
        let payload = try JSONEncoder().encode(gallery)
        let existing = try context.fetch(FetchDescriptor<GalleryCacheRecord>(
            predicate: #Predicate { $0.galleryID == id }
        ))
        if let row = existing.first {
            row.payload = payload
            row.cachedAt = .now
        } else {
            context.insert(GalleryCacheRecord(galleryID: id, payload: payload, cachedAt: .now))
        }
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
