import SwiftUI

struct PaginationBar: View {
    let page: Int
    let totalCount: Int
    var pageSize = 25
    let onSelect: (Int) -> Void

    @State private var showJump = false
    @Environment(\.tr) private var tr

    private var totalPages: Int { max(1, (totalCount + pageSize - 1) / pageSize) }

    var body: some View {
        HStack(spacing: 2) {
            pageButton("backward.end.fill", label: tr("첫 페이지", "First page"), target: 1, enabled: page > 1)
            pageButton("chevron.left", label: tr("이전 페이지", "Previous page"), target: page - 1, enabled: page > 1)

            Button {
                showJump = true
            } label: {
                Text(verbatim: "\(page) / \(totalPages)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 88, minHeight: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("페이지 \(page) / \(totalPages)", "Page \(page) of \(totalPages)"))
            .accessibilityHint(tr("페이지 번호를 입력해 이동합니다", "Enter a page number to jump"))

            pageButton("chevron.right", label: tr("다음 페이지", "Next page"), target: page + 1, enabled: page < totalPages)
            pageButton("forward.end.fill", label: tr("마지막 페이지", "Last page"), target: totalPages, enabled: page < totalPages)
        }
        .padding(.horizontal, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .pageJumpAlert(isPresented: $showJump, current: page, total: totalPages, onJump: onSelect)
    }

    private func pageButton(_ symbol: String, label: String, target: Int, enabled: Bool) -> some View {
        Button {
            onSelect(target)
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 40, height: 40)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

private struct PageJumpAlert: ViewModifier {
    @Binding var isPresented: Bool
    let current: Int
    let total: Int
    let onJump: (Int) -> Void

    @State private var input = ""
    @Environment(\.tr) private var tr

    func body(content: Content) -> some View {
        content
            .alert(tr("페이지 이동", "Go to page"), isPresented: $isPresented) {
                TextField(tr("페이지 번호 (1 ~ \(total))", "Page number (1-\(total))"), text: $input)
                    .keyboardType(.numberPad)
                Button(tr("이동", "Go")) {
                    if let target = Int(input.filter(\.isNumber)), (1...total).contains(target) {
                        onJump(target)
                    }
                }
                Button(tr("취소", "Cancel"), role: .cancel) {}
            } message: {
                Text(tr("1부터 \(total)까지 입력하세요", "Enter a number from 1 to \(total)"))
            }
            .onChange(of: isPresented) { _, presented in
                if presented { input = String(current) }
            }
    }
}

extension View {
    /// An alert that asks for a 1-based page number and reports it when valid.
    func pageJumpAlert(isPresented: Binding<Bool>, current: Int, total: Int, onJump: @escaping (Int) -> Void) -> some View {
        modifier(PageJumpAlert(isPresented: isPresented, current: current, total: total, onJump: onJump))
    }
}
