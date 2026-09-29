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
    @State private var entryCount = 0
    @State private var missingCount = 0
    @State private var attempt = 0
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
                    if entryCount > 0 {
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
        .task(id: LoadTrigger(revision: app.library.historyRevision, attempt: attempt)) { await load() }
    }

    private struct LoadTrigger: Equatable {
        let revision: Int
        let attempt: Int
    }

    @ViewBuilder
    private var content: some View {
        if galleries.isEmpty {
            if isLoading {
                LoadingView()
            } else if missingCount > 0 {
                ContentUnavailableView {
                    Label(tr("기록을 불러오지 못했습니다", "Could not load the history"), systemImage: "wifi.exclamationmark")
                } description: {
                    Text(tr("네트워크 상태를 확인하고 다시 시도해보세요", "Check your connection and try again"))
                } actions: {
                    Button(tr("다시 시도", "Retry")) { attempt += 1 }
                        .buttonStyle(.glass)
                }
            } else {
                ContentUnavailableView(
                    tr("최근 본 작품이 없습니다", "No recently viewed galleries"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(tr("작품을 열람하면 이곳에 최근 기록이 저장됩니다", "Galleries you view will appear here"))
                )
            }
        } else if cardMode == .grid {
            GalleryCollection(galleries: galleries, mode: .grid, position: $position, onRemove: { remove($0.id) }) {
                missingFooter
            }
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
                missingFooter
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var missingFooter: some View {
        if missingCount > 0 && !isLoading {
            VStack(spacing: 8) {
                Text(tr("기록 \(missingCount)개를 불러오지 못했습니다", "\(missingCount) entries could not be loaded"))
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
                Button(tr("다시 시도", "Retry"), systemImage: "arrow.clockwise") { attempt += 1 }
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
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
        entryCount = ids.count
        guard !ids.isEmpty else {
            galleries = []
            missingCount = 0
            return
        }

        var byID = app.library.cachedGalleries(ids: ids)
        galleries = ids.compactMap { byID[$0] }
        missingCount = ids.count - galleries.count

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
            missingCount = ids.count - galleries.count
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
            entryCount = 0
            missingCount = 0
        } catch {
            Self.logger.error("Could not clear history: \(error.localizedDescription)")
            app.showToast(tr("기록을 삭제하지 못했습니다.", "Could not delete the history entry."))
        }
    }
}
