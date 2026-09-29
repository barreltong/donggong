import SwiftData
import SwiftUI

@main
struct DonggongApp: App {
    @State private var app: AppModel
    @AppStorage(ThemeMode.key) private var theme = ThemeMode.fallback
    @AppStorage(AppLanguage.key) private var language = AppLanguage.fallback

    init() {
        CoreBridge.start()
        Task.detached(priority: .background) {
            ImagePipeline.shared.trimDiskCache()
        }
        let (container, failed) = Persistence.makeContainer()
        _app = State(initialValue: AppModel(library: LibraryStore(container: container), storageFailed: failed))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(\.tr, Tr(language: language))
                .appTheme(theme)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.tr) private var tr
    @AppStorage(ThemeMode.key) private var theme = ThemeMode.fallback
    @State private var showStorageWarning = false

    var body: some View {
        @Bindable var app = app

        TabView(selection: $app.selectedTab) {
            Tab(value: AppTab.home) {
                HomeView()
            } label: {
                Label(tr("홈", "Home"), systemImage: "house")
            }
            Tab(value: AppTab.favorites) {
                FavoritesView()
            } label: {
                Label(tr("즐겨찾기", "Favorites"), systemImage: "heart")
            }
            Tab(value: AppTab.history) {
                HistoryView()
            } label: {
                Label(tr("기록", "History"), systemImage: "clock.arrow.circlepath")
            }
            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Label(tr("설정", "Settings"), systemImage: "gearshape")
            }
        }
        .toastOverlay(bottomPadding: 72)
        .sheet(item: $app.detail, onDismiss: app.detailDismissed) { route in
            GalleryDetailView(
                galleryID: route.galleryID,
                onStartReading: { page in app.openReader(route.galleryID, page: page) },
                onSearch: { tag in app.search(tag) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .appTheme(theme)
            .toastOverlay()
        }
        .fullScreenCover(item: $app.reader) { route in
            ReaderView(route: route)
                .appTheme(theme)
        }
        .onAppear { showStorageWarning = app.storageFailed }
        .alert(tr("저장소를 열 수 없습니다", "Storage unavailable"), isPresented: $showStorageWarning) {
            Button(tr("확인", "OK"), role: .cancel) {}
        } message: {
            Text(tr(
                "이번 실행 동안의 즐겨찾기와 기록은 저장되지 않습니다. 기기 저장 공간을 확인한 뒤 앱을 다시 실행해주세요.",
                "Favorites and history from this session will not be saved. Check the device storage and relaunch the app."
            ))
        }
    }
}
