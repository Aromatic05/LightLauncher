import SwiftUI

struct AbbreviationRow: View {
    let key: String
    let values: [String]
    let isEditing: Bool
    @Binding var editingValues: String
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)
            if isEditing {
                TextField("编辑匹配词", text: $editingValues)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack(spacing: 8) {
                    Button("取消") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text(values.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Button("删除") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// Old AbbreviationRow code, kept for reference
// struct AbbreviationRow: View {
//     let key: String
//     let values: [String]
//     let isEditing: Bool
//     @Binding var editingValues: String
//     let onEdit: () -> Void
//     let onSave: () -> Void
//     let onCancel: () -> Void
//     let onDelete: () -> Void
    
//     var body: some View {
//         HStack(spacing: 12) {
//             Text(key)
//                 .font(.system(.body, design: .monospaced))
//                 .fontWeight(.semibold)
//                 .foregroundColor(.accentColor)
//                 .frame(width: 60, alignment: .leading)
//             Image(systemName: "arrow.right")
//                 .foregroundColor(.secondary)
//                 .font(.caption)
//             if isEditing {
//                 TextField("编辑匹配词", text: $editingValues)
//                     .textFieldStyle(RoundedBorderTextFieldStyle())
//                 HStack(spacing: 8) {
//                     Button("保存") {
//                         onSave()
//                     }
//                     .buttonStyle(.borderedProminent)
//                     .controlSize(.small)
//                     Button("取消") {
//                         onCancel()
//                     }
//                     .buttonStyle(.bordered)
//                     .controlSize(.small)
//                 }
//             } else {
//                 Text(values.joined(separator: ", "))
//                     .font(.subheadline)
//                     .foregroundColor(.secondary)
//                     .frame(maxWidth: .infinity, alignment: .leading)
//                 HStack(spacing: 8) {
//                     Button("编辑") {
//                         onEdit()
//                     }
//                     .buttonStyle(.bordered)
//                     .controlSize(.small)
//                     Button("删除") {
//                         onDelete()
//                     }
//                     .buttonStyle(.bordered)
//                     .controlSize(.small)
//                     .foregroundColor(.red)
//                 }
//             }
//         }
//         .padding(.horizontal, 16)
//         .padding(.vertical, 12)
//         .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
//         .cornerRadius(10)
//     }
// }
