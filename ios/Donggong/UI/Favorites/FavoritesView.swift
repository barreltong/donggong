import SwiftUI

struct FavoritesView: View {
    private enum Segment: Hashable {
        case galleries, tags
    }

    private struct LoadTrigger: Equatable {
        let ids: [Int64]
        let listing: ListingMode
        let page: Int
    }

    private static let pageSize = 25
    private static let fetchConcurrency = 8

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr
    @AppStorage(CardViewMode.key) private var cardMode = CardViewMode.fallback
    @AppStorage(ListingMode.key) private var listingMode = ListingMode.fallback

    @State private var segment = Segment.galleries
    @State private var page = 1
    @State private var loaded: [Int64: Gallery] = [:]
    @State private var isLoading = false
    @State private var loadGeneration = 0
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        let favorites = app.library.favorites
        let ids = favorites.galleryIDs
        let totalPages = max(1, (ids.count + Self.pageSize - 1) / Self.pageSize)
        let currentPage = min(page, totalPages)
        let visibleIDs = listingMode == .pagination ? pageSlice(ids, page: currentPage) : ids
        let visible = visibleIDs.compactMap { loaded[$0] }

        NavigationStack {
            VStack(spacing: 0) {
                Picker(tr("보기", "View"), selection: $segment) {
                    Text(tr("작품 (\(ids.count))", "Galleries (\(ids.count))")).tag(Segment.galleries)
                    Text(tr("태그 (\(favorites.chips.count))", "Tags (\(favorites.chips.count))")).tag(Segment.tags)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                switch segment {
                case .galleries:
                    galleryContent(ids: ids, visible: visible)
                case .tags:
                    tagContent(favorites.chips)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .navigationTitle(tr("즐겨찾기", "Favorites"))
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if segment == .galleries && listingMode == .pagination && !ids.isEmpty {
                    PaginationBar(page: currentPage, totalCount: ids.count, pageSize: Self.pageSize) { target in
                        page = target
                        position.scrollTo(edge: .top)
                    }
                }
            }
        }
        .task(id: LoadTrigger(ids: ids, listing: listingMode, page: currentPage)) {
            loaded = loaded.filter { ids.contains($0.key) }
            let first = listingMode == .pagination ? pageSlice(ids, page: currentPage) : Array(ids.prefix(Self.pageSize))
            await load(first)
        }
    }

    @ViewBuilder
    private func galleryContent(ids: [Int64], visible: [Gallery]) -> some View {
        if ids.isEmpty {
            ContentUnavailableView(
                tr("즐겨찾기한 작품이 없습니다", "No favorite galleries"),
                systemImage: "heart",
                description: Text(tr("작품 카드의 하트를 눌러 추가해보세요", "Tap the heart on a gallery card to add one"))
            )
        } else if visible.isEmpty && isLoading {
            LoadingView()
        } else {
            GalleryCollection(
                galleries: visible,
                mode: cardMode,
                position: $position,
                onReachEnd: { loadMore(ids: ids) }
            ) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func tagContent(_ chips: [String]) -> some View {
        if chips.isEmpty {
            ContentUnavailableView(
                tr("즐겨찾기한 태그가 없습니다", "No favorite tags"),
                systemImage: "tag.slash",
                description: Text(tr("태그를 길게 눌러 즐겨찾기에 추가할 수 있습니다", "Touch and hold a tag to add it to favorites"))
            )
        } else {
            ScrollView {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        TagChip(chip, forceFavorite: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func pageSlice(_ ids: [Int64], page: Int) -> [Int64] {
        let start = min((page - 1) * Self.pageSize, ids.count)
        return Array(ids[start..<min(start + Self.pageSize, ids.count)])
    }

    private func loadMore(ids: [Int64]) {
        guard listingMode == .scroll, !isLoading else { return }
        let next = Array(ids.lazy.filter { loaded[$0] == nil }.prefix(Self.pageSize))
        guard !next.isEmpty else { return }
        Task { await load(next) }
    }

    /// Fills `loaded` from the metadata cache first, then fetches the rest in small batches.
    private func load(_ ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        let cached = app.library.cachedGalleries(ids: ids)
        loaded.merge(cached) { _, new in new }

        let missing = ids.filter { cached[$0] == nil }
        for chunk in missing.chunks(of: Self.fetchConcurrency) {
            guard generation == loadGeneration else { return }
            let fetched = await CoreBridge.details(ids: Array(chunk))
            guard generation == loadGeneration else { return }
            for gallery in fetched {
                loaded[gallery.id] = gallery
                app.library.cacheGallery(gallery)
            }
        }
    }
}
