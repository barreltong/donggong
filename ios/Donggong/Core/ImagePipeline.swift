import CryptoKit
import ImageIO
import OSLog
import UIKit

/// Carries a decoded image across concurrency domains. UIImage is immutable once created.
struct DecodedImage: @unchecked Sendable {
    let image: UIImage
}

enum ImagePipelineError: Error {
    case undecodable
}

/// Loads images through the Go core, which applies the DPI bypass, and keeps a
/// memory cache of decoded images plus a disk cache of the original bytes.
final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    private static let diskLimit = 512 * 1024 * 1024
    private static let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "ImagePipeline")

    private let memory = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inflight: [String: Task<Data, any Error>] = [:]
    private var writesSinceTrim = 0
    private let directory: URL

    private init() {
        memory.totalCostLimit = 192 * 1024 * 1024
        directory = URL.cachesDirectory.appending(path: "images", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cachedImage(url: String, maxPixelWidth: CGFloat) -> DecodedImage? {
        memory.object(forKey: memoryKey(url, maxPixelWidth)).map(DecodedImage.init)
    }

    func image(url: String, maxPixelWidth: CGFloat) async throws -> DecodedImage {
        let key = memoryKey(url, maxPixelWidth)
        if let hit = memory.object(forKey: key) { return DecodedImage(image: hit) }

        let data = try await data(for: url)
        let decoded: DecodedImage
        do {
            decoded = try await BlockingWork.run { try Self.decode(data, maxPixelWidth: maxPixelWidth) }
        } catch {
            // A corrupt cached file would fail forever; drop it so the retry refetches.
            try? FileManager.default.removeItem(at: fileURL(for: url))
            throw error
        }
        let image = decoded.image
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memory.setObject(image, forKey: key, cost: cost)
        return decoded
    }

    /// Warms the disk cache without decoding.
    func prefetch(_ url: String) async {
        _ = try? await data(for: url)
    }

    func clear() async throws {
        memory.removeAllObjects()
        let directory = directory
        try await BlockingWork.run {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: directory.path(percentEncoded: false)) {
                try fileManager.removeItem(at: directory)
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Deletes the least recently used files until the cache fits its budget.
    func trimDiskCache() {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else {
            return
        }
        var entries = files.compactMap { file -> (url: URL, date: Date, size: Int)? in
            guard let values = try? file.resourceValues(forKeys: Set(keys)) else { return nil }
            return (file, values.contentModificationDate ?? .distantPast, values.totalFileAllocatedSize ?? 0)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > Self.diskLimit else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries where total > Self.diskLimit {
            do {
                try fileManager.removeItem(at: entry.url)
                total -= entry.size
            } catch {
                Self.logger.error("Could not trim cached image: \(error.localizedDescription)")
            }
        }
    }

    private func data(for url: String) async throws -> Data {
        let task = lock.withLock { () -> Task<Data, any Error> in
            if let existing = inflight[url] { return existing }
            let file = fileURL(for: url)
            let task = Task<Data, any Error>.detached(priority: .userInitiated) {
                // Runs after the caller releases the lock, so removal always follows insertion.
                defer { self.lock.withLock { self.inflight[url] = nil } }
                if let cached = try? Data(contentsOf: file), !cached.isEmpty {
                    try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path(percentEncoded: false))
                    return cached
                }
                let fetched = try await CoreBridge.fetchBytes(url: url)
                do {
                    try fetched.write(to: file, options: .atomic)
                    if self.shouldTrimAfterWrite() { self.trimDiskCache() }
                } catch {
                    Self.logger.error("Could not cache image: \(error.localizedDescription)")
                }
                return fetched
            }
            inflight[url] = task
            return task
        }
        return try await task.value
    }

    /// Keeps the disk budget enforced during long sessions without scanning on every write.
    private func shouldTrimAfterWrite() -> Bool {
        lock.withLock {
            writesSinceTrim += 1
            guard writesSinceTrim >= 200 else { return false }
            writesSinceTrim = 0
            return true
        }
    }

    private func memoryKey(_ url: String, _ maxPixelWidth: CGFloat) -> NSString {
        "\(Int(maxPixelWidth))|\(url)" as NSString
    }

    private func fileURL(for url: String) -> URL {
        let digest = SHA256.hash(data: Data(url.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: name, directoryHint: .notDirectory)
    }

    /// Decodes at most `maxPixelWidth` pixels wide. Tall webtoon strips keep their full
    /// height because the limit applies to width, not to the longest side.
    private static func decode(_ data: Data, maxPixelWidth: CGFloat) throws -> DecodedImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { throw ImagePipelineError.undecodable }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        guard width > 0, height > 0 else { throw ImagePipelineError.undecodable }

        let scale = min(1, Double(maxPixelWidth) / width)
        let longestSide = (max(width, height) * scale).rounded(.up)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ImagePipelineError.undecodable
        }
        return DecodedImage(image: UIImage(cgImage: image))
    }
}
