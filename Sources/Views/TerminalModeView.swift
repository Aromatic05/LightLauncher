import SwiftUI
import AppKit

// MARK: - Terminal Mode Views
struct TerminalCommandInputView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 模式图标和标题
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("终端")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // 输入提示
            VStack(spacing: 12) {
                Text("输入终端命令，按回车执行")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if !searchText.isEmpty {
                    let cleanText = extractCleanText()
                    if !cleanText.isEmpty {
                        Text("将执行: \(cleanText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // 帮助文本
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "在终端应用中执行命令",
                    "支持 Terminal 和 iTerm2",
                    "删除 /t 前缀返回启动模式"
                ], id: \.self) { text in
                    HStack {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func extractCleanText() -> String {
        let prefix = "/t "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
