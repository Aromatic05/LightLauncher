import SwiftUI

// MARK: - 文件命令输入视图（空状态）
struct FileCommandInputView: View {
    let currentPath: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("File Browser")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Choose a starting directory to begin browsing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Navigation:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("• Enter:")
                            .fontWeight(.medium)
                        Text("Select directory or open file")
                    }
                    HStack {
                        Text("• Space:")
                            .fontWeight(.medium)
                        Text("Open in Finder")
                    }
                    HStack {
                        Text("• Type:")
                            .fontWeight(.medium)
                        Text("Filter directories")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - 日期格式化扩展
extension DateFormatter {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
