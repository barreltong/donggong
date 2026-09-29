import OSLog
import SwiftUI

/// Gallery metadata, tag groups, and page previews, shown in a sheet.
struct GalleryDetailView: View {
    let galleryID: Int64
    let onStartReading: (Int) -> Void
    let onSearch: (String) -> Void

    private enum Phase {
        case loading
        case loaded(Gallery)
        case failed
    }

    @State private var phase = Phase.loading
    @State private var attempt = 0
    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    private static let logger = Logger(subsystem: "io.github.devgaki.donggong", category: "GalleryDetail")

    var body: some View {
        Group {
            switch phase {
            case .loading:
                LoadingView()
            case .failed:
                ContentUnavailableView {
                    Label(tr("작품 정보를 불러올 수 없습니다.", "Unable to load gallery information."), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(tr("네트워크 상태를 확인하고 다시 시도해보세요", "Check your connection and try again"))
                } actions: {
                    Button(tr("다시 시도", "Retry")) { attempt += 1 }
                        .buttonStyle(.glass)
                }
            case .loaded(let gallery):
                content(gallery)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .task(id: attempt) { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            let gallery = try await CoreBridge.readerData(id: galleryID)
            phase = .loaded(gallery)
            do {
                try app.library.recordView(gallery)
            } catch {
                Self.logger.error("Could not record history: \(error.localizedDescription)")
            }
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("Gallery \(galleryID) failed: \(error.localizedDescription)")
            phase = .failed
        }
    }

    private func content(_ gallery: Gallery) -> some View {
        let isFavorite = app.library.favorites.containsGallery(gallery.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header(gallery)
                infoTiles(gallery)
                actions(gallery, isFavorite: isFavorite)

                tagGroup(tr("작가", "Artists"), labels: gallery.artists.map { "artist:\($0)" })
                tagGroup(tr("그룹 / 서클", "Groups / Circles"), labels: gallery.groups.map { "group:\($0)" })
                tagGroup(tr("시리즈 / 원작", "Series / Original Work"), labels: gallery.parodys.map { "series:\($0)" })
                tagGroup(tr("캐릭터", "Characters"), labels: gallery.characters.map { "character:\($0)" })
                tagGroup(tr("태그 목록", "Tags"), labels: gallery.tags)

                if !gallery.images.isEmpty {
                    previews(gallery)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func header(_ gallery: Gallery) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(url: gallery.thumbnail, maxPixelWidth: 300)
                .frame(width: 96, height: 136)
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
                if !gallery.artists.isEmpty {
                    Label(gallery.artists.joined(separator: ", "), systemImage: "paintbrush.pointed")
                        .labelStyle(CompactLabelStyle())
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    if !gallery.type.isEmpty { Pill(text: gallery.type) }
                    if !gallery.language.isEmpty { Pill(text: gallery.language) }
                    if gallery.pageCount > 0 { Pill(text: "\(gallery.pageCount)p") }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(palette.card, in: .rect(cornerRadius: 16))
    }

    private func infoTiles(_ gallery: Gallery) -> some View {
        HStack(spacing: 8) {
            Button {
                app.copyGalleryID(gallery.id, tr: tr)
            } label: {
                infoTile(
                    symbol: "doc.on.doc",
                    caption: tr("작품 ID (탭하여 복사)", "Gallery ID (tap to copy)"),
                    value: "#\(gallery.id)"
                )
            }
            .buttonStyle(.plain)

            if !gallery.language.isEmpty {
                infoTile(symbol: "character.bubble", caption: tr("언어", "Language"), value: gallery.language.uppercased())
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func infoTile(symbol: String, caption: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline)
                .frame(width: 32, height: 32)
                .background(palette.chip, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                Text(verbatim: value)
                    .font(.footnote.weight(.bold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(palette.card, in: .rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
    }

    private func actions(_ gallery: Gallery, isFavorite: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                onStartReading(0)
            } label: {
                Label(tr("열람 시작", "Start reading"), systemImage: "book.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(palette.accent, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)

            Button {
                app.toggleGalleryFavorite(gallery, tr: tr)
            } label: {
                Label(
                    isFavorite ? tr("즐겨찾기 완료", "Added to favorites") : tr("즐겨찾기", "Add to favorites"),
                    systemImage: isFavorite ? "heart.fill" : "heart"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isFavorite ? Palette.favorite : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.chip, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isFavorite ? tr("즐겨찾기됨", "Favorite") : "")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func tagGroup(_ title: String, labels: [String]) -> some View {
        if !labels.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(labels, id: \.self) { label in
                        TagChip(label, onSearch: onSearch)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card.opacity(0.6), in: .rect(cornerRadius: 16))
        }
    }

    private func previews(_ gallery: Gallery) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("전체 페이지 미리보기 (\(gallery.images.count)p)", "All page previews (\(gallery.images.count)p)"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 4)], spacing: 4) {
                ForEach(Array(gallery.images.enumerated()), id: \.offset) { index, image in
                    Button {
                        onStartReading(index)
                    } label: {
                        Color.clear
                            .aspectRatio(0.72, contentMode: .fit)
                            .overlay { RemoteImage(url: image.url, hash: image.imageHash, maxPixelWidth: 240) }
                            .clipShape(.rect(cornerRadius: 8))
                            .overlay(alignment: .topLeading) {
                                Text(verbatim: "\(index + 1)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.65), in: .rect(bottomTrailingRadius: 6))
                                    .clipShape(.rect(topLeadingRadius: 8))
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("\(index + 1) 페이지부터 읽기", "Read from page \(index + 1)"))
                }
            }
        }
    }
}
