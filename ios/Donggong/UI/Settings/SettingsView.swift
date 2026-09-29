import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum UpdateState: Equatable {
        case idle
        case checking
        case available(ReleaseInfo)
        case upToDate
    }

    private static let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "Settings")

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    @AppStorage(AppLanguage.key) private var appLanguage = AppLanguage.fallback
    @AppStorage(ThemeMode.key) private var themeMode = ThemeMode.fallback
    @AppStorage(CardViewMode.key) private var cardMode = CardViewMode.fallback
    @AppStorage(ListingMode.key) private var listingMode = ListingMode.fallback
    @AppStorage(GalleryLanguage.key) private var galleryLanguage = GalleryLanguage.fallback
    @AppStorage(ReaderMode.key) private var readerMode = ReaderMode.fallback
    @AppStorage(DoublePageOrder.key) private var doublePageOrder = DoublePageOrder.fallback
    @AppStorage(PageTurnDirection.key) private var pageTurnDirection = PageTurnDirection.fallback

    @State private var updateState = UpdateState.idle
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var confirmReset = false
    @State private var pendingImport: [FavoriteKey]?
    @State private var confirmImport = false
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                browsingSection
                aboutSection
                dataSection
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(tr("설정", "Settings"))
            .disabled(isWorking)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "donggong_backup.json"
        ) { result in
            switch result {
            case .success:
                app.showToast(tr("백업 파일이 저장되었습니다.", "Backup file saved."))
            case .failure(let error):
                guard !isCancellation(error) else { return }
                Self.logger.error("Export failed: \(error.localizedDescription)")
                app.showToast(tr("내보내기에 실패했습니다.", "Export failed."))
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .plainText]) { result in
            switch result {
            case .success(let url):
                importBackup(from: url)
            case .failure(let error):
                guard !isCancellation(error) else { return }
                Self.logger.error("Import picker failed: \(error.localizedDescription)")
                app.showToast(tr("지원하지 않거나 손상된 백업 파일입니다.", "Unsupported or corrupted backup file."))
            }
        }
        .alert(
            tr("즐겨찾기 가져오기", "Import favorites"),
            isPresented: $confirmImport,
            presenting: pendingImport
        ) { keys in
            Button(tr("가져오기", "Import"), role: .destructive) { applyImport(keys) }
            Button(tr("취소", "Cancel"), role: .cancel) {}
        } message: { keys in
            Text(tr(
                "현재 즐겨찾기 \(app.library.favorites.keys.count)개가 백업의 \(keys.count)개로 교체됩니다.",
                "Your \(app.library.favorites.keys.count) favorites will be replaced by the \(keys.count) in the backup."
            ))
        }
        .alert(tr("데이터 초기화", "Reset app data"), isPresented: $confirmReset) {
            Button(tr("초기화", "Reset"), role: .destructive, action: resetData)
            Button(tr("취소", "Cancel"), role: .cancel) {}
        } message: {
            Text(tr(
                "즐겨찾기, 최근 본 기록, 검색 기록이 모두 영구 삭제됩니다. 계속하시겠습니까?",
                "Favorites, history, and searches will be permanently deleted. Continue?"
            ))
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        Section(tr("화면 및 테마", "Appearance")) {
            Picker(selection: $appLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { Text($0.label).tag($0) }
            } label: {
                Label(tr("앱 언어", "App language"), systemImage: "globe")
            }
            Picker(selection: $themeMode) {
                ForEach(ThemeMode.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("테마 모드", "Theme"), systemImage: "circle.lefthalf.filled")
            }
            Picker(selection: $cardMode) {
                ForEach(CardViewMode.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("카드 표시 모드", "Card layout"), systemImage: "rectangle.grid.1x2")
            }
        }
        .listRowBackground(palette.card)
    }

    private var browsingSection: some View {
        Section(tr("탐색 및 리더 설정", "Browsing and reader")) {
            Picker(selection: $listingMode) {
                ForEach(ListingMode.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("목록 스크롤 방식", "List navigation"), systemImage: "arrow.up.arrow.down")
            }
            Picker(selection: $galleryLanguage) {
                ForEach(GalleryLanguage.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("기본 언어 필터", "Default gallery language"), systemImage: "character.bubble")
            }
            Picker(selection: $readerMode) {
                ForEach(ReaderMode.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("기본 리더 모드", "Default reader mode"), systemImage: "book")
            }
            Picker(selection: $doublePageOrder) {
                ForEach(DoublePageOrder.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("두 쪽 보기 순서", "Spread order"), systemImage: "book.pages")
            }
            Picker(selection: $pageTurnDirection) {
                ForEach(PageTurnDirection.allCases, id: \.self) { Text($0.label(tr)).tag($0) }
            } label: {
                Label(tr("페이지 넘김 방향", "Page turn direction"), systemImage: "hand.point.left")
            }
        }
        .listRowBackground(palette.card)
    }

    private var aboutSection: some View {
        Section(tr("앱 정보 및 업데이트", "App info and updates")) {
            LabeledContent {
                Text(verbatim: "v\(AppUpdater.currentVersion)")
            } label: {
                Label(tr("동공 (Donggong)", "Donggong"), systemImage: "app.badge")
            }

            switch updateState {
            case .idle, .upToDate:
                Button(action: checkForUpdate) {
                    Label(tr("업데이트 확인", "Check for updates"), systemImage: "arrow.triangle.2.circlepath")
                }
            case .checking:
                HStack {
                    Label(tr("업데이트 확인 중...", "Checking for updates..."), systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    ProgressView()
                }
            case .available(let release):
                Link(destination: release.pageURL) {
                    Label(
                        tr("새 버전 v\(release.version) 사용 가능, 릴리스 페이지 열기", "Version \(release.version) available, open the release page"),
                        systemImage: "arrow.down.circle"
                    )
                }
            }
        }
        .listRowBackground(palette.card)
    }

    private var dataSection: some View {
        Section(tr("데이터 및 백업 관리", "Data and backups")) {
            actionRow(tr("즐겨찾기 내보내기", "Export favorites"), detail: tr("JSON 백업 파일로 저장", "Save a JSON backup"), symbol: "square.and.arrow.up") {
                exportFavorites()
            }
            actionRow(tr("즐겨찾기 가져오기", "Import favorites"), detail: tr("Donggong 또는 Pupil JSON 백업 복원", "Restore a Donggong or Pupil JSON backup"), symbol: "square.and.arrow.down") {
                isImporting = true
            }
            actionRow(tr("캐시 삭제", "Clear cache"), detail: tr("이미지와 갤러리 캐시만 삭제", "Clear only image and gallery caches"), symbol: "trash", role: .destructive) {
                clearCache()
            }
            actionRow(tr("데이터 초기화", "Reset app data"), detail: tr("즐겨찾기, 기록, 설정을 모두 삭제", "Remove favorites, history, and settings"), symbol: "arrow.counterclockwise", role: .destructive) {
                confirmReset = true
            }
        }
        .listRowBackground(palette.card)
    }

    private func actionRow(
        _ title: String,
        detail: String,
        symbol: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
        .foregroundStyle(role == .destructive ? Color.red : Color.primary)
    }

    // MARK: Actions

    private func checkForUpdate() {
        updateState = .checking
        Task {
            do {
                let release = try await AppUpdater.latestRelease()
                if AppUpdater.isNewer(release.version, than: AppUpdater.currentVersion) {
                    updateState = .available(release)
                } else {
                    updateState = .upToDate
                    app.showToast(tr("최신 버전입니다.", "You are on the latest version."))
                }
            } catch {
                Self.logger.error("Update check failed: \(error.localizedDescription)")
                updateState = .idle
                app.showToast(tr("업데이트를 확인할 수 없습니다.", "Could not check for updates."))
            }
        }
    }

    private func exportFavorites() {
        do {
            exportDocument = BackupDocument(data: try FavoritesBackup.encode(app.library.favorites))
            isExporting = true
        } catch {
            Self.logger.error("Backup encoding failed: \(error.localizedDescription)")
            app.showToast(tr("내보내기에 실패했습니다.", "Export failed."))
        }
    }

    private func importBackup(from url: URL) {
        Task {
            let decoded = try? await BlockingWork.run { try FavoritesBackup.decode(readBackupFile(url)) }
            guard let keys = decoded else {
                app.showToast(tr("지원하지 않거나 손상된 백업 파일입니다.", "Unsupported or corrupted backup file."))
                return
            }
            // Importing replaces every favorite, so it waits for confirmation.
            pendingImport = keys
            confirmImport = true
        }
    }

    private func applyImport(_ keys: [FavoriteKey]) {
        pendingImport = nil
        do {
            try app.library.replaceFavorites(with: keys)
            app.showToast(tr("즐겨찾기를 가져왔습니다.", "Favorites imported."))
        } catch {
            Self.logger.error("Import failed: \(error.localizedDescription)")
            app.showToast(tr("즐겨찾기를 저장하지 못했습니다.", "Could not save the favorites."))
        }
    }

    private func clearCache() {
        do {
            try app.library.clearGalleryCache()
        } catch {
            Self.logger.error("Gallery cache clear failed: \(error.localizedDescription)")
            app.showToast(tr("캐시를 삭제하지 못했습니다.", "Could not clear the cache."))
            return
        }
        app.home.reset()
        clearImages(success: tr("캐시가 삭제되었습니다.", "Cache cleared."))
    }

    private func resetData() {
        do {
            try app.library.resetAll()
        } catch {
            Self.logger.error("Reset failed: \(error.localizedDescription)")
            app.showToast(tr("데이터를 초기화하지 못했습니다.", "Could not reset the data."))
            return
        }
        SettingsStore.resetAll()
        app.home.reset()
        clearImages(success: tr("데이터가 초기화되었습니다.", "Data reset complete."))
    }

    /// Runs after the database step has committed, so an image cache failure is reported without undoing it.
    private func clearImages(success: String) {
        isWorking = true
        let failure = tr("이미지 캐시를 삭제하지 못했습니다.", "Could not clear the image cache.")
        Task {
            defer { isWorking = false }
            do {
                try await ImagePipeline.shared.clear()
                app.showToast(success)
            } catch {
                Self.logger.error("Image cache clear failed: \(error.localizedDescription)")
                app.showToast(failure)
            }
        }
    }

    private func isCancellation(_ error: any Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }
}

/// Reads a user-picked file through its security scope, refusing anything over the backup size limit.
private func readBackupFile(_ url: URL) throws -> Data {
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
        if scoped { url.stopAccessingSecurityScopedResource() }
    }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: FavoritesBackup.maxFileSize + 1) ?? Data()
    guard data.count <= FavoritesBackup.maxFileSize else {
        throw CocoaError(.fileReadTooLarge)
    }
    return data
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
