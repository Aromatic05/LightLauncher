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

struct ClipItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        HStack(spacing: 8) {
            switch item {
            case .text(let str):
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.accentColor)
                Text(str)
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .file(let url):
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}
