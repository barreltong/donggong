import Core
import Foundation

enum CoreBridgeError: LocalizedError {
    case go(String)
    case invalidURL
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .go(let message): message
        case .invalidURL: "Invalid URL"
        case .emptyResponse: "Empty response"
        }
    }
}

/// Runs blocking work on a dedicated GCD queue so it never parks a Swift
/// concurrency cooperative thread. Every Go call blocks until its network I/O ends.
enum BlockingWork {
    private static let queue = DispatchQueue(
        label: "io.github.devgaki.donggong.blocking",
        qos: .userInitiated,
        attributes: .concurrent
    )

    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result(catching: work))
            }
        }
    }
}

enum CoreBridge {
    static func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            CoreInit()
        }
    }

    static func list(page: Int, language: String) async throws -> GalleryListResult {
        let json = try await callString { error in CoreGetListJson(page, language, error) }
        return try decode(GalleryListResult.self, from: json)
    }

    static func search(query: String, page: Int, defaultLanguage: String) async throws -> GalleryListResult {
        let json = try await callString { error in CoreSearchJson(query, page, defaultLanguage, error) }
        return try decode(GalleryListResult.self, from: json)
    }

    static func detail(id: Int64) async throws -> Gallery {
        let json = try await callString { error in CoreGetDetailJson(id, error) }
        return try decode(Gallery.self, from: json)
    }

    static func readerData(id: Int64) async throws -> Gallery {
        let json = try await callString { error in CoreGetReaderDataJson(id, error) }
        return try decode(Gallery.self, from: json)
    }

    /// Fetches details for several galleries at once and drops the ones that fail.
    static func details(ids: [Int64]) async -> [Gallery] {
        await withTaskGroup(of: Gallery?.self) { group in
            for id in ids {
                group.addTask { try? await detail(id: id) }
            }
            var result: [Gallery] = []
            for await gallery in group {
                if let gallery { result.append(gallery) }
            }
            return result
        }
    }

    static func tagSuggestions(query: String) async -> [TagSuggestion] {
        guard let json = try? await callString({ error in CoreGetTagSuggestionsJson(query, error) }) else {
            return []
        }
        return (try? decode([TagSuggestion].self, from: json)) ?? []
    }

    static func resolveImageURL(hash: String, forceRefresh: Bool) async -> String? {
        let url = try? await callString { error in CoreResolveImageUrl(hash, forceRefresh, error) }
        guard let url, url.hasPrefix("https://") else { return nil }
        return url
    }

    static func fetchBytes(url: String) async throws -> Data {
        guard url.hasPrefix("https://") else { throw CoreBridgeError.invalidURL }
        return try await BlockingWork.run {
            var error: NSError?
            let data = CoreFetchBytes(url, &error)
            if let error { throw CoreBridgeError.go(error.localizedDescription) }
            guard let data, !data.isEmpty else { throw CoreBridgeError.emptyResponse }
            return data
        }
    }

    private static func callString(_ body: @escaping @Sendable (NSErrorPointer) -> String) async throws -> String {
        try await BlockingWork.run {
            var error: NSError?
            let result = body(&error)
            if let error { throw CoreBridgeError.go(error.localizedDescription) }
            return result
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
