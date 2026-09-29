import SwiftUI

enum ImageFetch {
    static let maxRetries = 3
    static let retryBaseDelay = 1500

    /// Loads one image with the same recovery as the Android app: gg.js rotates the
    /// CDN subdomain and key, so the first failure re-resolves the URL from the hash
    /// without spending a retry, then up to three retries back off exponentially.
    static func load(url: String, hash: String?, maxPixelWidth: CGFloat) async -> DecodedImage? {
        guard !url.isEmpty else { return nil }
        var current = url
        var refreshed = false
        var attempt = 0
        while !Task.isCancelled {
            do {
                return try await ImagePipeline.shared.image(url: current, maxPixelWidth: maxPixelWidth)
            } catch {
                if Task.isCancelled { return nil }
                if !refreshed, let hash, !hash.isEmpty {
                    refreshed = true
                    if let fresh = await CoreBridge.resolveImageURL(hash: hash, forceRefresh: true), fresh != current {
                        current = fresh
                        continue
                    }
                }
                if attempt >= maxRetries { return nil }
                try? await Task.sleep(for: .milliseconds(retryBaseDelay << attempt))
                attempt += 1
            }
        }
        return nil
    }
}

enum ImagePhase {
    case empty
    case loading
    case success(UIImage)
    case failure
}

private struct ImageLoadKey: Hashable {
    let url: String
    let attempt: Int
}

/// A network image with a loading placeholder and a tap-to-retry state.
struct RemoteImage: View {
    let url: String
    var hash: String?
    var maxPixelWidth: CGFloat = 600
    var contentMode: ContentMode = .fill

    @State private var phase: ImagePhase
    @State private var phaseURL: String
    @State private var attempt = 0
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    init(url: String, hash: String? = nil, maxPixelWidth: CGFloat = 600, contentMode: ContentMode = .fill) {
        self.url = url
        self.hash = hash
        self.maxPixelWidth = maxPixelWidth
        self.contentMode = contentMode
        _phase = State(initialValue: Self.initialPhase(url: url, maxPixelWidth: maxPixelWidth))
        _phaseURL = State(initialValue: url)
    }

    var body: some View {
        // A reused view can receive a new url before its load task restarts.
        let current = phaseURL == url ? phase : Self.initialPhase(url: url, maxPixelWidth: maxPixelWidth)
        ZStack {
            switch current {
            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            case .loading:
                palette.chip
                ProgressView()
                    .controlSize(.small)
            case .failure:
                palette.chip
                Button {
                    attempt += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("이미지를 불러오지 못했습니다. 눌러서 다시 시도", "Image failed to load. Tap to retry"))
            case .empty:
                palette.chip
                Image(systemName: "photo")
                    .foregroundStyle(palette.secondaryText.opacity(0.6))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: isLoaded(current))
        .task(id: ImageLoadKey(url: url, attempt: attempt)) {
            let target = url
            if phaseURL != target {
                phaseURL = target
                phase = Self.initialPhase(url: target, maxPixelWidth: maxPixelWidth)
            }
            if target.isEmpty || (isLoaded(phase) && attempt == 0) { return }
            phase = .loading
            if let decoded = await ImageFetch.load(url: target, hash: hash, maxPixelWidth: maxPixelWidth) {
                phase = .success(decoded.image)
            } else if !Task.isCancelled {
                phase = .failure
            }
        }
    }

    private func isLoaded(_ phase: ImagePhase) -> Bool {
        if case .success = phase { return true }
        return false
    }

    private static func initialPhase(url: String, maxPixelWidth: CGFloat) -> ImagePhase {
        if url.isEmpty { return .empty }
        if let cached = ImagePipeline.shared.cachedImage(url: url, maxPixelWidth: maxPixelWidth) {
            return .success(cached.image)
        }
        return .loading
    }
}
