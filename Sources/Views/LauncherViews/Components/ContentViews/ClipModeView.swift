import QuickLook
import QuickLookUI
import SwiftUI

struct ClipModeView: View {
    @ObservedObject var viewModel: LauncherViewModel

    private var clipController: ClipModeController? {
        ModeRegistry.shared[ClipModeController.self]
    }

    private var isSnippetMode: Bool {
        clipController?.isSnippetMode ?? false
    }

    /// 预览项由 VM 状态唯一推导:
    /// - `selectedIndex` 变化时 `displayableItems` 已对应切换,直接取选中项
    /// - `isSnippetMode` 切换后 `selectedIndex` 被 controller 重置为 0,`displayableItems` 也已刷新,自动落到首项
    /// 不再需要 @State 跟踪 + onChange 兜底,VM 的 `viewSyncToken` 是唯一重渲染信号
    private var previewItem: (any DisplayableItem)? {
        let items = viewModel.displayableItems
        if items.indices.contains(viewModel.selectedIndex) {
            return items[viewModel.selectedIndex]
        }
        return items.first
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                // 顶部模式切换和清空按钮
                HStack {
                    Button(action: { clipController?.isSnippetMode = false }) {
                        Text("剪贴板")
                            .fontWeight(isSnippetMode ? .regular : .bold)
                            .foregroundColor(isSnippetMode ? .secondary : .accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { clipController?.isSnippetMode = true }) {
                        Text("片段")
                            .fontWeight(isSnippetMode ? .bold : .regular)
                            .foregroundColor(isSnippetMode ? .accentColor : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                    clearButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ResultsListView(viewModel: viewModel)
            }

            Divider()

            // 预览区域
            VStack {
                if let item = previewItem {
                    previewView(for: item)
                } else {
                    Text("暂无可预览的内容")
                        .foregroundColor(.secondary)
                        .padding()
                }
                Spacer()
            }
            .frame(minWidth: 320, maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var clearButton: some View {
        if let clipController = clipController {
            if !clipController.isSnippetMode, !ClipboardManager.shared.getHistory().isEmpty {
                Button("清空") {
                    ClipboardManager.shared.clearHistory()
                    clipController.handleInput(arguments: "")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
                .font(.caption)
            } else if clipController.isSnippetMode, !SnippetManager.shared.getSnippets().isEmpty {
                Button("清空") {
                    SnippetManager.shared.clearSnippets()
                    clipController.handleInput(arguments: "")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func previewView(for item: any DisplayableItem) -> some View {
        if let clip = item as? ClipboardItem {
            switch clip.payload {
            case .text:
                TextEditor(text: .constant(clip.textValue ?? ""))
                    .font(.system(size: 15))
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .frame(minHeight: 200)
            case .file:
                if let url = clip.fileURL {
                    QuickLookPreview(url: url)
                } else {
                    Text("文件预览不可用")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        } else if let snippet = item as? SnippetItem {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snippet.name)
                        .font(.title3)
                        .bold()
                    if !snippet.keyword.isEmpty {
                        Text("/ " + snippet.keyword)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                TextEditor(text: .constant(snippet.snippet))
                    .font(.system(size: 15))
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .frame(minHeight: 120)
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)
        } else {
            Text(item.title)
                .font(.body)
                .padding()
        }
    }
}

// QuickLook 文件预览 SwiftUI 封装
struct QuickLookPreview: NSViewRepresentable {
    typealias NSViewType = QLPreviewView

    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.autoresizingMask = [.width, .height]
        previewView?.previewItem = url as NSURL
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: ()) {
        nsView.previewItem = nil
    }
}
