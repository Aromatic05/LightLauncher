import QuickLook
import QuickLookUI
import SwiftUI

struct ClipModeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var previewItem: ClipboardItem? = nil

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                // 历史记录标题和清空按钮
                HStack {
                    Text("剪切板历史")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let clipController = viewModel.controllers[.clip] as? ClipModeController,
                        !ClipboardManager.shared.getHistory().isEmpty
                    {
                        Button("清空") {
                            ClipboardManager.shared.clearHistory()
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
                        if let item = viewModel.displayableItems[idx] as? ClipboardItem {
                            previewItem = item
                        } else {
                            previewItem = nil
                        }
                    })
            }

            Divider()

            // 预览区域
            VStack {
                let itemToShow: ClipboardItem? = {
                    if let item = previewItem {
                        return item
                    } else if let first = viewModel.displayableItems.first as? ClipboardItem {
                        return first
                    } else {
                        return nil
                    }
                }()
                if let item = itemToShow {
                    switch item {
                    case .text(let str):
                        ScrollView {
                            Text(str)
                                .padding()
                        }
                    case .file(let url):
                        QuickLookPreview(url: url)
                    }
                } else {
                    Text("暂无可预览的剪切板项")
                        .foregroundColor(.secondary)
                        .padding()
                }
                Spacer()
            }
            .frame(minWidth: 320, maxWidth: .infinity)
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
