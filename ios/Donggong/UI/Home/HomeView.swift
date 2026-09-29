import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr
    @AppStorage(CardViewMode.key) private var cardMode = CardViewMode.fallback
    @AppStorage(ListingMode.key) private var listingMode = ListingMode.fallback
    @AppStorage(GalleryLanguage.key) private var language = GalleryLanguage.fallback

    @FocusState private var searchFocused: Bool
    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        let model = app.home

        content(model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            .overlay(alignment: .top) {
                if searchFocused {
                    SearchSuggestionPanel(model: model, isFocused: $searchFocused, onSubmit: submit)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HomeSearchHeader(
                    model: model,
                    isFocused: $searchFocused,
                    cardMode: cardMode,
                    onCycleCardMode: {
                        searchFocused = false
                        cardMode = cardMode.next
                    },
                    onSubmit: submit
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if listingMode == .pagination && model.totalCount > 0 {
                    PaginationBar(page: model.page, totalCount: model.totalCount) { target in
                        model.goToPage(target)
                    }
                }
            }
            .task(id: language) { await model.ensureLoaded() }
            .onChange(of: model.scrollToTopRequest) {
                position.scrollTo(edge: .top)
            }
    }

    @ViewBuilder
    private func content(_ model: HomeModel) -> some View {
        if model.galleries.isEmpty {
            // A scroll view keeps pull to refresh available on the empty and error states.
            ScrollView {
                emptyState(model)
                    .containerRelativeFrame([.horizontal, .vertical])
            }
            .refreshable { await model.refresh() }
        } else {
            GalleryCollection(
                galleries: model.galleries,
                mode: cardMode,
                position: $position,
                isLoading: model.isLoading,
                onReachEnd: model.loadMore
            ) {
                if listingMode == .scroll {
                    ListFooter(isLoading: model.isLoading, failed: model.loadFailed, onRetry: model.retry)
                }
            }
            .refreshable { await model.refresh() }
            .overlay(alignment: .top) {
                if listingMode == .pagination && model.isLoading {
                    ProgressView()
                        .padding(12)
                        .glassEffect(.regular, in: .circle)
                        .padding(.top, 8)
                        .accessibilityLabel(tr("불러오는 중", "Loading"))
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(_ model: HomeModel) -> some View {
        if model.isLoading {
            LoadingView(caption: tr("작품 목록 불러오는 중...", "Loading galleries..."))
        } else if model.loadFailed {
            ContentUnavailableView {
                Label(tr("목록을 불러오지 못했습니다", "Could not load galleries"), systemImage: "wifi.exclamationmark")
            } description: {
                Text(tr("네트워크 상태를 확인하고 다시 시도해보세요", "Check your connection and try again"))
            } actions: {
                Button(tr("다시 시도", "Retry"), action: model.retry)
                    .buttonStyle(.glass)
            }
        } else {
            ContentUnavailableView(
                tr("검색 결과가 없습니다", "No results found"),
                systemImage: "magnifyingglass",
                description: Text(tr("다른 검색어나 언어로 다시 시도해보세요", "Try another search or language"))
            )
        }
    }

    private func submit(_ text: String) {
        let normalized = TagInfo.normalizeQuery(text)
        if let id = Int64(normalized), id > 0 {
            searchFocused = false
            app.openReader(id)
        } else {
            searchFocused = false
            app.home.submit(normalized)
        }
    }
}

/// The search field, the card layout switch, and the favorite tag shortcuts.
private struct HomeSearchHeader: View {
    @Bindable var model: HomeModel
    var isFocused: FocusState<Bool>.Binding
    let cardMode: CardViewMode
    let onCycleCardMode: () -> Void
    let onSubmit: (String) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(palette.secondaryText)
                        .accessibilityHidden(true)
                    TextField(tr("태그, 작가, 작품 검색...", "Search tags, artists, galleries..."), text: $model.query)
                        .focused(isFocused)
                        .submitLabel(.search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { onSubmit(model.query) }
                        .accessibilityLabel(tr("검색", "Search"))
                    if !model.query.isEmpty {
                        Button {
                            model.query = ""
                            onSubmit("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(palette.secondaryText)
                                .frame(width: 32, height: 32)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("검색어 지우기", "Clear search"))
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .frame(minHeight: 48)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button(action: onCycleCardMode) {
                    Image(systemName: cardMode.symbolName)
                        .font(.body.weight(.medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(tr("카드 표시 모드", "Card layout"))
                .accessibilityValue(cardMode.label(tr))
            }
            .padding(.horizontal, 10)

            let chips = app.library.favorites.chips
            if !isFocused.wrappedValue && !chips.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            TagChip(chip, forceFavorite: true) { label in
                                model.query = label
                                onSubmit(label)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

/// Recent searches while the field is empty, tag suggestions while typing.
private struct SearchSuggestionPanel: View {
    @Bindable var model: HomeModel
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: (String) -> Void

    @State private var suggestions: [TagSuggestion] = []
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    private struct SuggestionRequest: Hashable {
        let query: String
    }

    var body: some View {
        let showRecent = model.query.isEmpty && !model.recentSearches.isEmpty

        Group {
            if showRecent || !suggestions.isEmpty {
                ViewThatFits(in: .vertical) {
                    rows(showRecent: showRecent)
                    ScrollView { rows(showRecent: showRecent) }
                }
                .frame(maxHeight: 360)
                .background(palette.card, in: .rect(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(palette.outline.opacity(0.35), lineWidth: 0.6) }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .padding(.horizontal, 10)
            }
        }
        .task(id: SuggestionRequest(query: model.query)) {
            suggestions = []
            let query = model.query
            let lastToken = query.lastIndex(of: " ").map { String(query[query.index(after: $0)...]) } ?? query
            let term = lastToken.firstIndex(of: ":").map { String(lastToken[lastToken.index(after: $0)...]) } ?? lastToken
            guard term.count >= 2 else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let result = await CoreBridge.tagSuggestions(query: term)
            guard !Task.isCancelled else { return }
            suggestions = result
        }
    }

    private func rows(showRecent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if showRecent {
                HStack {
                    sectionTitle(tr("최근 검색", "Recent searches"))
                    Spacer()
                    Button(tr("모두 지우기", "Clear all")) { model.clearRecentSearches() }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.mini)
                }
                .padding(.trailing, 8)

                ForEach(model.recentSearches, id: \.self) { recent in
                    HStack(spacing: 0) {
                        Button {
                            model.query = recent
                            onSubmit(recent)
                        } label: {
                            rowLabel(symbol: "clock.arrow.circlepath", text: recent)
                        }
                        .buttonStyle(.plain)
                        Button {
                            model.removeRecentSearch(recent)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.secondaryText)
                                .frame(width: 36, height: 36)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("\(recent) 삭제", "Delete \(recent)"))
                    }
                }
            }

            if !suggestions.isEmpty {
                sectionTitle(tr("추천 검색어", "Suggestions"))
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        apply(suggestion)
                    } label: {
                        HStack {
                            rowLabel(symbol: TagInfo(parsing: suggestion.fullTag).symbolName, text: suggestion.fullTag)
                            if suggestion.count > 0 {
                                Text(verbatim: "\(suggestion.count)")
                                    .font(.caption2.weight(.medium).monospacedDigit())
                                    .foregroundStyle(palette.secondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(palette.chip, in: .capsule)
                                    .padding(.trailing, 10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func rowLabel(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .imageScale(.small)
                .foregroundStyle(palette.secondaryText)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .contentShape(.rect)
    }

    /// Replaces the token being typed with the suggestion and leaves room for the next one.
    private func apply(_ suggestion: TagSuggestion) {
        var parts = model.query.split(whereSeparator: \.isWhitespace).map(String.init)
        let tag = TagInfo.normalizeLabel(suggestion.fullTag)
        if parts.isEmpty {
            parts = [tag]
        } else {
            parts[parts.count - 1] = tag
        }
        model.query = parts.joined(separator: " ") + " "
        isFocused.wrappedValue = true
    }
}
