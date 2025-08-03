import SwiftUI

// MARK: - 片段项行视图
struct SnippetItemRow: View {
    let snippet: SnippetItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            snippetInfo
            actionButtons
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var snippetInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snippet.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                if !snippet.keyword.isEmpty {
                    Text(snippet.keyword)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            Text(snippet.snippet)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button("编辑") {
                onEdit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("删除") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
    }
}
