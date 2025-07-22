import SwiftUI

struct SearchBoxView: View {
    @Binding var searchText: String
    @FocusState private var isSearchFieldFocused: Bool
    let mode: LauncherMode
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField(mode.placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .focused($isSearchFieldFocused)
            
            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(isSearchFieldFocused ? 0.6 : 0), lineWidth: 2)
                )
        )
        .padding(.horizontal, 24)
        .onAppear {
            isSearchFieldFocused = true
        }
        .onChange(of: isSearchFieldFocused) { focused in
            if !focused {
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
    }
}
