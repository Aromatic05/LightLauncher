import SwiftUI
import AppKit

struct ClipModeResultsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let clipboardHistory: [ClipboardItem] = ClipboardManager.shared.getHistory()
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                        if let clipItem = item as? ClipboardItem {
                            ClipItemRowView(
                                item: clipItem,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                handleClipAction(clipItem)
                            }
                            .focusable(false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focusable(false)
            }
            .focusable(false)
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func handleClipAction(_ item: ClipboardItem) {
        switch item {
        case .text(let str):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(str, forType: .string)
        case .file(let url):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        // 可扩展：自动粘贴、关闭窗口等
    }
}

