import AppKit
import SwiftUI

struct SearchBoxView: View {
    @ObservedObject var viewModel = LauncherViewModel.shared
    @Binding var searchText: String
    @FocusState private var isSearchFieldFocused: Bool
    @State private var focusSequenceTask: Task<Void, Never>?
    let mode: LauncherMode

    // 接收来自父视图 LauncherView 的窗口状态
    let isWindowKey: Bool

    let onClear: () -> Void

    @MainActor
    static func moveCaretToEnd(in responder: NSResponder?) -> Bool {
        guard let editor = responder as? NSTextView else { return false }

        let textLength = editor.string.count
        editor.setSelectedRange(NSRange(location: textLength, length: 0))
        editor.scrollRangeToVisible(NSRange(location: textLength, length: 0))
        return true
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            TextField(mode.placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isSearchFieldFocused)  // 绑定焦点

            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.accentColor.opacity(isSearchFieldFocused ? 0.6 : 0), lineWidth: 2)
                )
        )
        .padding(.horizontal, 24)

        .onChange(of: isWindowKey) { newIsKey in
            if newIsKey {
                scheduleProgrammaticFocus(after: 100_000_000)
            }
        }
        .onReceive(viewModel.focusSearchField) { _ in
            scheduleProgrammaticFocus()
        }
        .onDisappear {
            focusSequenceTask?.cancel()
        }
    }

    private func scheduleProgrammaticFocus(after delayNanoseconds: UInt64 = 0) {
        focusSequenceTask?.cancel()
        focusSequenceTask = Task { @MainActor in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            isSearchFieldFocused = true
            try? await Task.sleep(nanoseconds: 10_000_000)
            guard !Task.isCancelled else { return }
            _ = SearchBoxView.moveCaretToEnd(in: NSApp.keyWindow?.firstResponder)
        }
    }
}
