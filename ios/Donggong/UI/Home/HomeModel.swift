import Observation
import OSLog

/// The home list: the latest galleries for the default language, or search results.
@MainActor
@Observable
final class HomeModel {
    var query = ""
    private(set) var activeQuery = ""
    private(set) var page = 1
    private(set) var totalCount = 0
    private(set) var galleries: [Gallery] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var recentSearches: [String] = []
    /// Bumped when a fresh result set replaces the list, so the view can scroll to the top.
    private(set) var scrollToTopRequest = 0

    @ObservationIgnored private var requestVersion = 0
    @ObservationIgnored private var requestedLanguage: GalleryLanguage?
    @ObservationIgnored private var lastRequest = (page: 1, replace: true)
    private let library: LibraryStore
    private let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "HomeModel")

    init(library: LibraryStore) {
        self.library = library
    }

    var canLoadMore: Bool {
        ListingMode.stored == .scroll && !isLoading && !loadFailed && galleries.count < totalCount
    }

    /// Loads the first page when the list is empty or the default language changed.
    func ensureLoaded() async {
        recentSearches = library.recentSearches()
        let language = GalleryLanguage.stored
        if language == requestedLanguage && (isLoading || !galleries.isEmpty) { return }
        await load(page: 1, replace: true)
    }

    func refresh() async {
        await load(page: 1, replace: true)
    }

    func loadMore() {
        guard canLoadMore else { return }
        Task { await load(page: page + 1, replace: false) }
    }

    func retry() {
        let request = lastRequest
        Task { await load(page: request.page, replace: request.replace) }
    }

    func goToPage(_ target: Int) {
        Task { await load(page: target, replace: true) }
    }

    func submit(_ raw: String) {
        let normalized = TagInfo.normalizeQuery(raw)
        // Invalidate in-flight pages for the previous query before anything else runs.
        requestVersion += 1
        query = raw
        activeQuery = normalized
        if !normalized.isEmpty {
            do {
                try library.addRecentSearch(normalized)
            } catch {
                logger.error("Could not save recent search: \(error.localizedDescription)")
            }
            recentSearches = library.recentSearches()
        }
        Task { await load(page: 1, replace: true) }
    }

    func removeRecentSearch(_ query: String) {
        do {
            try library.removeRecentSearch(query)
        } catch {
            logger.error("Could not remove recent search: \(error.localizedDescription)")
        }
        recentSearches = library.recentSearches()
    }

    func clearRecentSearches() {
        do {
            try library.clearRecentSearches()
        } catch {
            logger.error("Could not clear recent searches: \(error.localizedDescription)")
        }
        recentSearches = library.recentSearches()
    }

    /// Drops all loaded state so the next appearance reloads from scratch.
    func reset() {
        requestVersion += 1
        query = ""
        activeQuery = ""
        page = 1
        totalCount = 0
        galleries = []
        recentSearches = []
        requestedLanguage = nil
        lastRequest = (1, true)
        isLoading = false
        loadFailed = false
    }

    private func load(page target: Int, replace: Bool) async {
        if isLoading && !replace { return }
        requestVersion += 1
        let version = requestVersion
        let query = activeQuery
        let language = GalleryLanguage.stored
        let listing = ListingMode.stored
        requestedLanguage = language
        lastRequest = (target, replace)
        isLoading = true
        loadFailed = false
        defer {
            if version == requestVersion { isLoading = false }
        }

        do {
            let result = if query.isEmpty {
                try await CoreBridge.list(page: target, language: language.rawValue)
            } else {
                try await CoreBridge.search(query: query, page: target, defaultLanguage: language.rawValue)
            }
            guard version == requestVersion else { return }
            totalCount = result.totalCount
            if listing == .pagination || replace {
                galleries = result.galleries.uniquedByID()
            } else {
                let existing = Set(galleries.map(\.id))
                galleries += result.galleries.filter { !existing.contains($0.id) }.uniquedByID()
            }
            page = target
            if replace { scrollToTopRequest += 1 }
        } catch {
            guard version == requestVersion else { return }
            logger.error("Gallery list failed: \(error.localizedDescription)")
            if replace {
                // Stale results under a new query or page would look like the answer to it.
                galleries = []
                totalCount = 0
            }
            loadFailed = true
        }
    }
}
