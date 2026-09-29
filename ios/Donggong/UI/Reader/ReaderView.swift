import OSLog
import SwiftUI

struct ReaderView: View {
    let route: ReaderRoute

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tr) private var tr
    @Environment(\.colorScheme) private var appColorScheme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var gallery: Gallery?
    @State private var loadFailed = false
    @State private var loadAttempt = 0
    @State private var mode = ReaderMode.stored
    @State private var order = DoublePageOrder.stored
    @State private var direction = PageTurnDirection.stored
    @State private var currentPage = 0
    /// The page or spread index the scroll view is on; spreads use `page / 2`.
    @State private var scrolledID: Int?
    /// The page to restore after the scroll view is rebuilt for a new mode or direction.
    @State private var restorePage = 0
    @State private var showControls = false
    @State private var showDetails = false
    @State private var showJump = false
    @State private var pendingSearch: String?
    @State private var prefetchTask: Task<Void, Never>?
    @State private var pickerMode = ReaderMode.stored
    @State private var sliderValue = 0.0

    private static let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "Reader")

    private var images: [GalleryImage] { gallery?.images ?? [] }

    /// VoiceOver users cannot rely on tapping the page, so the controls stay up for them.
    private var controlsVisible: Bool { showControls || voiceOverEnabled }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let gallery, !gallery.images.isEmpty {
                pages
                    .ignoresSafeArea()
            } else if loadFailed || gallery != nil {
                failureView
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if controlsVisible || gallery == nil || images.isEmpty {
                controls
                    .transition(.opacity)
            }
        }
        .accessibilityAction(.escape) { dismiss() }
        .environment(\.colorScheme, .dark)
        .statusBarHidden(!controlsVisible)
        .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
        .task(id: loadAttempt) { await load() }
        .onChange(of: scrolledID) { _, id in
            guard let id, !images.isEmpty else { return }
            let page = mode == .doublePage ? id * 2 : id
            currentPage = min(max(page, 0), images.count - 1)
        }
        .onChange(of: currentPage) {
            sliderValue = Double(currentPage)
            schedulePrefetch()
        }
        .onChange(of: sliderValue) {
            let page = Int(sliderValue.rounded())
            if page != currentPage { jump(to: page) }
        }
        .onChange(of: pickerMode) { changeMode(pickerMode) }
        .onDisappear { prefetchTask?.cancel() }
        .sheet(isPresented: $showDetails, onDismiss: runPendingSearch) {
            GalleryDetailView(
                galleryID: route.galleryID,
                onStartReading: { page in
                    showDetails = false
                    jump(to: page)
                },
                onSearch: { tag in
                    pendingSearch = tag
                    showDetails = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, appColorScheme)
            .toastOverlay()
        }
        .pageJumpAlert(isPresented: $showJump, current: currentPage + 1, total: max(images.count, 1)) { page in
            jump(to: page - 1)
        }
        .toastOverlay(bottomPadding: controlsVisible ? 170 : 24)
    }

    // MARK: Pages

    private var pages: some View {
        ScrollViewReader { proxy in
            pageScroller
                .scrollIndicators(.hidden)
                .onAppear {
                    let target = anchorID(for: restorePage)
                    let anchor = scrollAnchor
                    scrolledID = target
                    proxy.scrollTo(target, anchor: anchor)
                    // Lazy stacks may not have laid out the target on the first pass.
                    Task { proxy.scrollTo(target, anchor: anchor) }
                }
        }
        .id(LayoutKey(mode: mode, direction: direction))
    }

    private var scrollAnchor: UnitPoint {
        mode == .webtoon ? .top : .center
    }

    @ViewBuilder
    private var pageScroller: some View {
        let reset = mode == .doublePage ? currentPage / 2 : currentPage
        switch mode {
        case .webtoon:
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(images.indices, id: \.self) { index in
                        ReaderPageView(slots: [images[index]], label: pageLabel(index), resetToken: 0, onTap: toggleControls)
                            .aspectRatio(images[index].aspectRatio, contentMode: .fit)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID, anchor: scrollAnchor)
        case .verticalPage:
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(images.indices, id: \.self) { index in
                        ReaderPageView(slots: [images[index]], label: pageLabel(index), resetToken: reset, onTap: toggleControls)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledID, anchor: scrollAnchor)
        case .horizontalPage:
            horizontalPager(count: images.count) { index in
                ReaderPageView(slots: [images[index]], label: pageLabel(index), resetToken: reset, onTap: toggleControls)
            }
        case .doublePage:
            horizontalPager(count: (images.count + 1) / 2) { spread in
                ReaderPageView(slots: spreadSlots(spread), label: spreadLabel(spread), resetToken: reset, onTap: toggleControls)
            }
        }
    }

    /// A horizontal pager. Turning pages to the right lays it out right to left,
    /// while each page keeps a left-to-right layout so spreads are not mirrored.
    private func horizontalPager<Page: View>(count: Int, @ViewBuilder page: @escaping (Int) -> Page) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    page(index)
                        .environment(\.layoutDirection, .leftToRight)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledID, anchor: scrollAnchor)
        .environment(\.layoutDirection, direction == .right ? .rightToLeft : .leftToRight)
    }

    private func spreadSlots(_ spread: Int) -> [GalleryImage?] {
        let first = images[spread * 2]
        let second = spread * 2 + 1 < images.count ? images[spread * 2 + 1] : nil
        return order == .japanese ? [second, first] : [first, second]
    }

    private func pageLabel(_ index: Int) -> String {
        tr("\(index + 1) / \(images.count) 페이지", "Page \(index + 1) of \(images.count)")
    }

    private func spreadLabel(_ spread: Int) -> String {
        let first = spread * 2 + 1
        let last = min(first + 1, images.count)
        return first == last
            ? pageLabel(first - 1)
            : tr("\(first)-\(last) / \(images.count) 페이지", "Pages \(first)-\(last) of \(images.count)")
    }

    private var failureView: some View {
        ContentUnavailableView {
            Label(tr("이미지를 불러올 수 없습니다.", "Unable to load images."), systemImage: "photo.badge.exclamationmark")
        } description: {
            Text(tr("네트워크 상태를 확인하고 다시 시도해보세요", "Check your connection and try again"))
        } actions: {
            Button(tr("다시 시도", "Retry")) {
                gallery = nil
                loadFailed = false
                loadAttempt += 1
            }
            .buttonStyle(.glass)
        }
        .foregroundStyle(.white)
    }

    // MARK: Controls

    private var controls: some View {
        VStack {
            topBar
            Spacer()
            if controlsVisible && !images.isEmpty {
                bottomBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var topBar: some View {
        let isFavorite = app.library.favorites.containsGallery(route.galleryID)

        return HStack(spacing: 4) {
            barButton("chevron.backward", label: tr("뒤로", "Back")) { dismiss() }

            Text(gallery?.title ?? "")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if let gallery {
                barButton(isFavorite ? "heart.fill" : "heart",
                          label: isFavorite ? tr("즐겨찾기에서 제거", "Remove from favorites") : tr("즐겨찾기에 추가", "Add to favorites"),
                          tint: isFavorite ? Palette.favorite : .white) {
                    app.toggleGalleryFavorite(gallery, tr: tr)
                }
                barButton("info.circle", label: tr("작품 정보", "Gallery details")) { showDetails = true }
            }
            if mode != .webtoon && !images.isEmpty {
                barButton(direction == .left ? "hand.point.left" : "hand.point.right",
                          label: tr("페이지 넘김 방향", "Page turn direction"),
                          value: direction.label(tr)) {
                    restorePage = currentPage
                    direction = direction == .left ? .right : .left
                }
            }
            if mode == .doublePage {
                Button {
                    order = order == .japanese ? .international : .japanese
                } label: {
                    Text(order == .japanese ? tr("우→좌", "R→L") : tr("좌→우", "L→R"))
                        .font(.caption.weight(.bold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("두 쪽 보기 순서", "Spread order"))
                .accessibilityValue(order.label(tr))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                showJump = true
            } label: {
                Text(verbatim: "\(currentPage + 1) / \(images.count)")
                    .font(.footnote.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("페이지 \(currentPage + 1) / \(images.count)", "Page \(currentPage + 1) of \(images.count)"))
            .accessibilityHint(tr("페이지 번호를 입력해 이동합니다", "Enter a page number to jump"))

            if images.count > 1 {
                Slider(value: $sliderValue, in: 0...Double(images.count - 1), step: 1)
                .tint(.white)
                .accessibilityLabel(tr("페이지", "Page"))
                .accessibilityValue(tr("\(currentPage + 1) / \(images.count)", "\(currentPage + 1) of \(images.count)"))
            }

            Picker(tr("리더 모드", "Reader mode"), selection: $pickerMode) {
                ForEach(ReaderMode.allCases, id: \.self) { item in
                    Text(item.shortLabel(tr)).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .foregroundStyle(.white)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func barButton(
        _ symbol: String,
        label: String,
        value: String? = nil,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }

    // MARK: Actions

    private func load() async {
        do {
            let loaded = try await CoreBridge.readerData(id: route.galleryID)
            let start = loaded.images.isEmpty ? 0 : min(max(route.page, 0), loaded.images.count - 1)
            currentPage = start
            restorePage = start
            sliderValue = Double(start)
            gallery = loaded
            schedulePrefetch()
            do {
                try app.library.recordView(loaded)
            } catch {
                Self.logger.error("Could not record history: \(error.localizedDescription)")
            }
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("Reader data failed: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
    }

    private func changeMode(_ newMode: ReaderMode) {
        guard newMode != mode else { return }
        restorePage = currentPage
        scrolledID = newMode == .doublePage ? currentPage / 2 : currentPage
        mode = newMode
        schedulePrefetch()
    }

    private func jump(to page: Int) {
        guard !images.isEmpty else { return }
        let target = min(max(page, 0), images.count - 1)
        currentPage = target
        scrolledID = anchorID(for: target)
    }

    private func anchorID(for page: Int) -> Int {
        mode == .doublePage ? page / 2 : page
    }

    private func runPendingSearch() {
        guard let tag = pendingSearch else { return }
        pendingSearch = nil
        app.search(tag)
    }

    /// Warms the disk cache for the next pages, dropping work for pages left behind.
    private func schedulePrefetch() {
        prefetchTask?.cancel()
        guard !images.isEmpty else { return }
        let spread = mode == .doublePage
        let first = spread ? (currentPage / 2 + 1) * 2 : currentPage + 1
        let count = spread ? 4 : 2
        let urls = images.dropFirst(first).prefix(count).map(\.url).filter { !$0.isEmpty }
        prefetchTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask { await ImagePipeline.shared.prefetch(url) }
                }
            }
        }
    }

    private struct LayoutKey: Hashable {
        let mode: ReaderMode
        let direction: PageTurnDirection
    }
}

/// Loads the images for one page or spread and shows them zoomable once all are ready.
private struct ReaderPageView: View {
    let slots: [GalleryImage?]
    let label: String
    let resetToken: Int
    let onTap: () -> Void

    /// Keyed by URL so swapping the spread order keeps what is already loaded.
    @State private var loaded: [String: UIImage]
    @State private var failed = false
    @State private var attempt = 0
    @Environment(\.tr) private var tr

    private static let decodeWidth: CGFloat = 2400

    init(slots: [GalleryImage?], label: String, resetToken: Int, onTap: @escaping () -> Void) {
        self.slots = slots
        self.label = label
        self.resetToken = resetToken
        self.onTap = onTap
        var cached: [String: UIImage] = [:]
        for slot in slots.compactMap({ $0 }) {
            if let hit = ImagePipeline.shared.cachedImage(url: slot.url, maxPixelWidth: Self.decodeWidth) {
                cached[slot.url] = hit.image
            }
        }
        _loaded = State(initialValue: cached)
    }

    private var isComplete: Bool {
        slots.allSatisfy { slot in slot.map { loaded[$0.url] != nil } ?? true }
    }

    var body: some View {
        Group {
            if isComplete {
                ZoomableImageView(
                    images: slots.map { slot in slot.flatMap { loaded[$0.url] } },
                    resetToken: resetToken,
                    onTap: onTap
                )
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityAddTraits([.isImage, .isButton])
                .accessibilityHint(tr("두 번 탭하면 컨트롤을 표시하거나 숨깁니다", "Double-tap to show or hide the controls"))
                .accessibilityAction { onTap() }
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(tr("페이지를 불러오지 못했습니다", "Could not load this page"))
                        .font(.subheadline)
                    Button(tr("다시 시도", "Retry")) { attempt += 1 }
                        .buttonStyle(.glass)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(tr("페이지 불러오는 중...", "Loading page..."))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .accessibilityElement(children: .combine)
                .accessibilityAction { onTap() }
            }
        }
        .task(id: attempt) { await load() }
    }

    private func load() async {
        failed = false
        let pending = slots.compactMap { $0 }.filter { loaded[$0.url] == nil }
        guard !pending.isEmpty else { return }
        let width = Self.decodeWidth
        await withTaskGroup(of: (String, DecodedImage?).self) { group in
            for image in pending {
                group.addTask {
                    let decoded = await ImageFetch.load(url: image.url, hash: image.imageHash, maxPixelWidth: width)
                    return (image.url, decoded)
                }
            }
            for await (url, decoded) in group {
                if let decoded {
                    loaded[url] = decoded.image
                } else if !Task.isCancelled {
                    failed = true
                }
            }
        }
    }
}
