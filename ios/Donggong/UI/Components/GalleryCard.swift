import SwiftUI

/// A gallery in one of the three list layouts. Tapping opens the reader; the
/// context menu offers details, favorites, and copying the id.
struct GalleryCard: View {
    let gallery: Gallery
    let mode: CardViewMode
    var onRemove: (() -> Void)?

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    var body: some View {
        let isFavorite = app.library.favorites.containsGallery(gallery.id)

        Group {
            if mode == .grid {
                gridLayout(isFavorite: isFavorite)
            } else {
                rowLayout(isFavorite: isFavorite, compact: mode == .compact)
            }
        }
        .background(palette.card, in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(palette.outline.opacity(0.3), lineWidth: 0.5)
        }
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
        .onTapGesture { app.openReader(gallery.id) }
        .contextMenu { menu(isFavorite: isFavorite) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func menu(isFavorite: Bool) -> some View {
        Button {
            app.openReader(gallery.id)
        } label: {
            Label(tr("열람 시작", "Start reading"), systemImage: "book")
        }
        Button {
            app.showDetail(gallery.id)
        } label: {
            Label(tr("작품 정보", "Gallery details"), systemImage: "info.circle")
        }
        Button {
            app.toggleGalleryFavorite(gallery, tr: tr)
        } label: {
            if isFavorite {
                Label(tr("즐겨찾기에서 제거", "Remove from favorites"), systemImage: "heart.slash")
            } else {
                Label(tr("즐겨찾기에 추가", "Add to favorites"), systemImage: "heart")
            }
        }
        Button {
            app.copyGalleryID(gallery.id, tr: tr)
        } label: {
            Label(tr("작품 ID 복사", "Copy gallery ID"), systemImage: "doc.on.doc")
        }
        if let onRemove {
            Button(role: .destructive, action: onRemove) {
                Label(tr("기록에서 삭제", "Remove from history"), systemImage: "trash")
            }
        }
    }

    private func gridLayout(isFavorite: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(0.72, contentMode: .fit)
                .overlay { RemoteImage(url: gallery.thumbnail, maxPixelWidth: 540) }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 42)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    idButton(onImage: true).padding(5)
                }
                .overlay(alignment: .topTrailing) {
                    favoriteButton(isFavorite: isFavorite, onImage: true).padding(5)
                }
                .overlay(alignment: .bottomLeading) {
                    if !gallery.language.isEmpty {
                        ImageBadge(text: gallery.language).padding(5)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if gallery.pageCount > 0 {
                        ImageBadge(text: "\(gallery.pageCount)p").padding(5)
                    }
                }
                .clipped()

            titleText
                .font(.caption.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
        }
    }

    private func rowLayout(isFavorite: Bool, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RemoteImage(url: gallery.thumbnail, maxPixelWidth: 300)
                .frame(width: compact ? 80 : 96, height: compact ? 114 : 136)
                .clipShape(.rect(cornerRadius: compact ? 10 : 12))
                .overlay(alignment: .bottomTrailing) {
                    if gallery.pageCount > 0 {
                        ImageBadge(text: "\(gallery.pageCount)p").padding(3)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    titleText
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    favoriteButton(isFavorite: isFavorite, onImage: false)
                }

                if !gallery.artists.isEmpty {
                    Label(gallery.artists.joined(separator: ", "), systemImage: "paintbrush.pointed")
                        .labelStyle(CompactLabelStyle())
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    idButton(onImage: false)
                    if !gallery.type.isEmpty {
                        Pill(text: gallery.type)
                    }
                    if !gallery.language.isEmpty {
                        Pill(text: gallery.language)
                    }
                }

                if !compact && !gallery.tags.isEmpty {
                    FlowLayout(spacing: 4, lineSpacing: 3) {
                        ForEach(Array(gallery.tags.prefix(6)), id: \.self) { tag in
                            TagChip(tag)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(compact ? 7 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: some View {
        Text(gallery.title)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(tr("열람을 시작합니다", "Starts reading"))
            .accessibilityAction { app.openReader(gallery.id) }
            .accessibilityAction(named: tr("작품 정보", "Gallery details")) { app.showDetail(gallery.id) }
    }

    private func favoriteButton(isFavorite: Bool, onImage: Bool) -> some View {
        Button {
            app.toggleGalleryFavorite(gallery, tr: tr)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isFavorite ? Palette.favorite : (onImage ? .white : palette.secondaryText))
                .frame(width: 30, height: 30)
                .background {
                    if onImage { Circle().fill(Color.black.opacity(0.5)) }
                }
                .contentShape(.circle)
                .symbolEffect(.bounce, value: isFavorite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? tr("즐겨찾기에서 제거", "Remove from favorites") : tr("즐겨찾기에 추가", "Add to favorites"))
    }

    private func idButton(onImage: Bool) -> some View {
        Button {
            app.copyGalleryID(gallery.id, tr: tr)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "doc.on.doc")
                    .imageScale(.small)
                Text(verbatim: "#\(gallery.id)")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(onImage ? .white : palette.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(onImage ? AnyShapeStyle(Color.black.opacity(0.65)) : AnyShapeStyle(palette.chip), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("작품 ID \(gallery.id) 복사", "Copy gallery ID \(gallery.id)"))
    }
}

/// A small dark badge drawn on top of a thumbnail.
struct ImageBadge: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(Color.black.opacity(0.65), in: .capsule)
    }
}

/// A small neutral capsule for metadata such as type and language.
struct Pill: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(verbatim: text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(palette.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(palette.chip, in: .capsule)
            .overlay { Capsule().strokeBorder(palette.outline.opacity(0.35), lineWidth: 0.5) }
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
