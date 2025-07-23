import SwiftUI
import AppKit

// MARK: - Web Mode Views
/// 当没有搜索结果时，显示的特定输入视图
struct WebCommandInputView: View {
    let currentQuery: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Open Web Page")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            VStack(spacing: 12) {
                Text("Enter a URL or search term")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if !currentQuery.isEmpty {
                    Text("Will open or search for: \(currentQuery)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "Full URLs and domain names are supported.",
                    "https:// prefix is added automatically.",
                    "Press Enter to open in your browser."
                ], id: \.self) { text in
                    HStack {
                        Circle().fill(Color.secondary).frame(width: 4, height: 4)
                        Text(text).font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}