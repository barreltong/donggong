import Accessibility
import Observation
import OSLog
import SwiftUI
import UIKit

enum AppTab: Hashable {
    case home, favorites, history, settings
}

struct ReaderRoute: Identifiable, Equatable {
    let id = UUID()
    let galleryID: Int64
    let page: Int
}

struct DetailRoute: Identifiable, Equatable {
    let id = UUID()
    let galleryID: Int64
}

/// App-wide navigation and actions shared by every screen.
@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .home
    var reader: ReaderRoute?
    var detail: DetailRoute?
    private(set) var toast: String?
    let storageFailed: Bool

    let library: LibraryStore
    let home: HomeModel

    @ObservationIgnored private var pendingReader: ReaderRoute?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "AppModel")

    init(library: LibraryStore, storageFailed: Bool) {
        self.library = library
        self.storageFailed = storageFailed
        home = HomeModel(library: library)
    }

    func openReader(_ galleryID: Int64, page: Int = 0) {
        let route = ReaderRoute(galleryID: galleryID, page: page)
        if detail != nil {
            // A cover cannot be presented while the sheet is still dismissing.
            pendingReader = route
            detail = nil
        } else {
            reader = route
        }
    }

    func detailDismissed() {
        guard let route = pendingReader else { return }
        pendingReader = nil
        reader = route
    }

    func showDetail(_ galleryID: Int64) {
        detail = DetailRoute(galleryID: galleryID)
    }

    /// Runs a search on the home tab from anywhere in the app.
    func search(_ query: String) {
        pendingReader = nil
        detail = nil
        reader = nil
        selectedTab = .home
        home.submit(query)
    }

    func toggleGalleryFavorite(_ gallery: Gallery, tr: Tr) {
        do {
            try library.toggleFavorite(.gallery(gallery.id), gallery: gallery)
        } catch {
            logger.error("Favorite toggle failed: \(error.localizedDescription)")
            showToast(tr("즐겨찾기를 저장하지 못했습니다.", "Could not save the favorite."))
        }
    }

    func toggleGalleryFavorite(id: Int64, tr: Tr) {
        do {
            try library.toggleFavorite(.gallery(id))
        } catch {
            logger.error("Favorite toggle failed: \(error.localizedDescription)")
            showToast(tr("즐겨찾기를 저장하지 못했습니다.", "Could not save the favorite."))
        }
    }

    func toggleTagFavorite(_ label: String, tr: Tr) {
        do {
            let added = try library.toggleFavorite(.tag(label))
            showToast(added
                ? tr("즐겨찾기에 추가되었습니다", "Added to favorites")
                : tr("즐겨찾기에서 제거되었습니다", "Removed from favorites"))
        } catch {
            logger.error("Favorite toggle failed: \(error.localizedDescription)")
            showToast(tr("즐겨찾기를 저장하지 못했습니다.", "Could not save the favorite."))
        }
    }

    func copyGalleryID(_ id: Int64, tr: Tr) {
        UIPasteboard.general.string = String(id)
        showToast(tr("작품 ID가 복사되었습니다 (\(id))", "Copied gallery ID (\(id))"))
    }

    func showToast(_ message: String) {
        toast = message
        AccessibilityNotification.Announcement(message).post()
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

struct ToastOverlay: ViewModifier {
    let bottomPadding: CGFloat
    @Environment(AppModel.self) private var app

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = app.toast {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, 24)
                    .padding(.bottom, bottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.spring(duration: 0.3), value: app.toast)
    }
}

extension View {
    func toastOverlay(bottomPadding: CGFloat = 16) -> some View {
        modifier(ToastOverlay(bottomPadding: bottomPadding))
    }
}
