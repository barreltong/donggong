import SwiftUI

/// Galleries as a vertical list or an adaptive grid, with infinite-scroll and
/// scroll-to-top hooks shared by the home, favorites and history screens.
struct GalleryCollection<Footer: View>: View {
    let galleries: [Gallery]
    let mode: CardViewMode
    @Binding var position: ScrollPosition
    var onReachEnd: (() -> Void)?
    var onRemove: ((Gallery) -> Void)?
    @ViewBuilder var footer: () -> Footer

    @State private var showScrollToTop = false
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            Group {
                if mode == .grid {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        cards(threshold: 6)
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        cards(threshold: 4)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            footer()
        }
        .scrollPosition($position)
        .scrollDismissesKeyboard(.immediately)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 900
        } action: { _, isFar in
            withAnimation(.snappy) { showScrollToTop = isFar }
        }
        .overlay(alignment: .bottomTrailing) {
            if showScrollToTop {
                Button {
                    withAnimation { position.scrollTo(edge: .top) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .padding(16)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(tr("맨 위로", "Scroll to top"))
            }
        }
    }

    private func cards(threshold: Int) -> some View {
        ForEach(Array(galleries.enumerated()), id: \.element.id) { index, gallery in
            GalleryCard(gallery: gallery, mode: mode, onRemove: onRemove.map { remove in { remove(gallery) } })
                .onAppear {
                    if index >= galleries.count - threshold { onReachEnd?() }
                }
        }
    }
}

extension GalleryCollection where Footer == EmptyView {
    init(
        galleries: [Gallery],
        mode: CardViewMode,
        position: Binding<ScrollPosition>,
        onReachEnd: (() -> Void)? = nil,
        onRemove: ((Gallery) -> Void)? = nil
    ) {
        self.init(galleries: galleries, mode: mode, position: position, onReachEnd: onReachEnd, onRemove: onRemove) {
            EmptyView()
        }
    }
}

/// A centered spinner with an optional caption.
struct LoadingView: View {
    var caption: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The spinner or retry button shown below a list while more pages load.
struct ListFooter: View {
    let isLoading: Bool
    let failed: Bool
    let onRetry: () -> Void
    @Environment(\.tr) private var tr

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if failed {
                Button(tr("다시 시도", "Retry"), systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
