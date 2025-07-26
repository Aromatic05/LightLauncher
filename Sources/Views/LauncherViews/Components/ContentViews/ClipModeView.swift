import QuickLook
import QuickLookUI
import SwiftUI


struct ClipModeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var clipController = ClipModeController.shared
    @State private var previewItem: (any DisplayableItem)? = nil

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                // 顶部模式切换和清空按钮
                HStack {
                    Button(action: { clipController.isSnippetMode = false }) {
                        Text("剪切板")
                            .fontWeight(clipController.isSnippetMode ? .regular : .bold)
                            .foregroundColor(clipController.isSnippetMode ? .secondary : .accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: { clipController.isSnippetMode = true }) {
                        Text("片段")
                            .fontWeight(clipController.isSnippetMode ? .bold : .regular)
                            .foregroundColor(clipController.isSnippetMode ? .accentColor : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                    if !clipController.isSnippetMode,
                        !ClipboardManager.shared.getHistory().isEmpty {
                        Button("清空") {
                            ClipboardManager.shared.clearHistory()
                            clipController.handleInput(arguments: "")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.blue)
                        .font(.caption)
                    } else if clipController.isSnippetMode,
                        !SnippetManager.shared.getSnippets().isEmpty {
                        Button("清空") {
                            SnippetManager.shared.clearSnippets()
                            clipController.handleInput(arguments: "")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.blue)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ResultsListView(
                    viewModel: viewModel,
                    onSelectionChanged: { idx in
                        if viewModel.displayableItems.indices.contains(idx) {
                            previewItem = viewModel.displayableItems[idx]
                        } else {
                            previewItem = nil
                        }
                    }
                )
                .onChange(of: clipController.isSnippetMode) { _ in
                    if let first = viewModel.displayableItems.first {
                        previewItem = first
                    } else {
                        previewItem = nil
                    }
                }
            }

            Divider()

            // 预览区域
            VStack {
                let itemToShow: (any DisplayableItem)? = {
                    if let item = previewItem {
                        return item
                    } else if let first = viewModel.displayableItems.first {
                        return first
                    } else {
                        return nil
                    }
                }()
                if let item = itemToShow {
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
    private func previewView(for item: any DisplayableItem) -> some View {
        if let clip = item as? ClipboardItem {
            switch clip {
            case .text(let str):
                TextEditor(text: .constant(str))
                    .font(.system(size: 15))
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .frame(minHeight: 200)
            case .file(let url):
                QuickLookPreview(url: url)
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
