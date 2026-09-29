import SwiftUI

/// Lays subviews out left to right and wraps them onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = arrange(subviews, maxWidth: maxWidth)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, lines.count - 1))
        let proposedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }
        return CGSize(width: proposedWidth ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (line.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            size.width = min(size.width, maxWidth)
            let proposedWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth, !current.items.isEmpty {
                lines.append(current)
                current = Line()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { lines.append(current) }
        return lines
    }
}

/// A tag such as `female:glasses`. Tapping searches it; the context menu toggles the favorite.
struct TagChip: View {
    let label: String
    var forceFavorite: Bool?
    var onSearch: ((String) -> Void)?

    @Environment(AppModel.self) private var app
    @Environment(\.palette) private var palette
    @Environment(\.tr) private var tr

    init(_ label: String, forceFavorite: Bool? = nil, onSearch: ((String) -> Void)? = nil) {
        self.label = label
        self.forceFavorite = forceFavorite
        self.onSearch = onSearch
    }

    var body: some View {
        let info = TagInfo(parsing: label)
        let isFavorite = forceFavorite ?? app.library.favorites.containsTag(label)

        Button(action: search) {
            HStack(spacing: 5) {
                Image(systemName: isFavorite ? "heart.fill" : info.symbolName)
                    .imageScale(.small)
                    .foregroundStyle(isFavorite ? palette.accent : palette.secondaryText)
                Text(info.displayLabel)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .font(.caption.weight(isFavorite ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isFavorite ? palette.chipSelected : palette.chip, in: .capsule)
            .overlay {
                Capsule().strokeBorder(
                    isFavorite ? palette.accent.opacity(0.5) : palette.outline.opacity(0.35),
                    lineWidth: 0.5
                )
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                app.toggleTagFavorite(label, tr: tr)
            } label: {
                if isFavorite {
                    Label(tr("즐겨찾기에서 제거", "Remove from favorites"), systemImage: "heart.slash")
                } else {
                    Label(tr("즐겨찾기에 추가", "Add to favorites"), systemImage: "heart")
                }
            }
            Button(action: search) {
                Label(tr("이 태그로 검색", "Search this tag"), systemImage: "magnifyingglass")
            }
        }
        .accessibilityLabel("\(kindName(info.kind)) \(info.displayLabel)")
        .accessibilityValue(isFavorite ? tr("즐겨찾기됨", "Favorite") : "")
        .accessibilityHint(tr("검색합니다", "Searches this tag"))
        .accessibilityAction(named: isFavorite ? tr("즐겨찾기에서 제거", "Remove from favorites") : tr("즐겨찾기에 추가", "Add to favorites")) {
            app.toggleTagFavorite(label, tr: tr)
        }
    }

    private func search() {
        if let onSearch {
            onSearch(label)
        } else {
            app.search(label)
        }
    }

    private func kindName(_ kind: String) -> String {
        switch kind {
        case "female": tr("여성", "Female")
        case "male": tr("남성", "Male")
        case "artist": tr("작가", "Artist")
        case "group": tr("그룹", "Group")
        case "series", "parody": tr("시리즈", "Series")
        case "character": tr("캐릭터", "Character")
        case "language": tr("언어", "Language")
        default: tr("태그", "Tag")
        }
    }
}
