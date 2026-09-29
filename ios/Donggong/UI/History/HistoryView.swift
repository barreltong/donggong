import OSLog
import SwiftUI

struct HistoryView: View {
    private static let fetchConcurrency = 8
    private static let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "History")

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr
    @AppStorage(CardViewMode.key) private var cardMode = CardViewMode.fallback

    @State private var galleries: [Gallery] = []
    @State private var isLoading = true
    @State private var confirmClear = false
    @State private var loadGeneration = 0
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background)
                .navigationTitle(tr("기록", "History"))
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if !galleries.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(tr("기록 삭제", "Clear history"), systemImage: "trash", role: .destructive) {
                                confirmClear = true
                            }
                        }
                    }
                }
                .alert(tr("기록을 모두 삭제할까요?", "Clear all history?"), isPresented: $confirmClear) {
                    Button(tr("삭제", "Delete"), role: .destructive, action: clearAll)
                    Button(tr("취소", "Cancel"), role: .cancel) {}
                } message: {
                    Text(tr(
                        "최근 본 작품 기록이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
                        "All recently viewed gallery history will be deleted. This action cannot be undone."
                    ))
                }
        }
        .task(id: app.library.historyRevision) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if galleries.isEmpty {
            if isLoading {
                LoadingView()
            } else {
                ContentUnavailableView(
                    tr("최근 본 작품이 없습니다", "No recently viewed galleries"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(tr("작품을 열람하면 이곳에 최근 기록이 저장됩니다", "Galleries you view will appear here"))
                )
            }
        } else if cardMode == .grid {
            GalleryCollection(galleries: galleries, mode: .grid, position: $position, onRemove: { remove($0.id) })
        } else {
            List {
                ForEach(galleries) { gallery in
                    GalleryCard(gallery: gallery, mode: cardMode, onRemove: { remove(gallery.id) })
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) { deleteAction(gallery) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) { deleteAction(gallery) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func deleteAction(_ gallery: Gallery) -> some View {
        Button(role: .destructive) {
            remove(gallery.id)
        } label: {
            Label(tr("삭제", "Delete"), systemImage: "trash")
        }
    }

    /// Shows cached metadata immediately, then fills in the rest from the network.
    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        let ids: [Int64]
        do {
            ids = try app.library.historyIDs()
        } catch {
            Self.logger.error("Could not read history: \(error.localizedDescription)")
            return
        }
        guard !ids.isEmpty else {
            galleries = []
            return
        }

        var byID = app.library.cachedGalleries(ids: ids)
        galleries = ids.compactMap { byID[$0] }

        let missing = ids.filter { byID[$0] == nil }
        for chunk in missing.chunks(of: Self.fetchConcurrency) {
            guard generation == loadGeneration else { return }
            let fetched = await CoreBridge.details(ids: Array(chunk))
            guard generation == loadGeneration else { return }
            for gallery in fetched {
                byID[gallery.id] = gallery
                app.library.cacheGallery(gallery)
            }
            galleries = ids.compactMap { byID[$0] }
        }
    }

    private func remove(_ id: Int64) {
        galleries.removeAll { $0.id == id }
        do {
            try app.library.removeHistory(id)
        } catch {
            Self.logger.error("Could not remove history entry: \(error.localizedDescription)")
            app.showToast(tr("기록을 삭제하지 못했습니다.", "Could not delete the history entry."))
        }
    }

    private func clearAll() {
        do {
            try app.library.clearHistory()
            galleries = []
        } catch {
            Self.logger.error("Could not clear history: \(error.localizedDescription)")
            app.showToast(tr("기록을 삭제하지 못했습니다.", "Could not delete the history entry."))
        }
    }
}
