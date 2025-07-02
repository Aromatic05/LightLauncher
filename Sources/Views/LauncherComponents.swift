import SwiftUI

// MARK: - 启动器头部视图
struct LauncherHeaderView: View {
    let mode: LauncherMode
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: mode.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(mode == .launch ? .secondary : .red)
                
                Text(mode.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(mode == .launch ? .primary : .red)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
    }
}

// MARK: - 搜索框视图
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

// MARK: - 空状态视图
struct EmptyStateView: View {
    let mode: LauncherMode
    let hasSearchText: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 40))
                .foregroundColor(emptyStateColor)
            
            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            if hasSearchText {
                Text("Try a different search term")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                VStack(spacing: 4) {
                    ForEach(getHelpText(for: mode), id: \.self) { helpText in
                        Text(helpText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateIcon: String {
        if hasSearchText {
            return mode == .launch ? "magnifyingglass" : "xmark.circle"
        } else {
            return mode == .launch ? "app.badge" : "xmark.circle"
        }
    }
    
    private var emptyStateColor: Color {
        if hasSearchText {
            return .secondary.opacity(0.5)
        } else {
            return mode == .launch ? .accentColor.opacity(0.7) : .red.opacity(0.7)
        }
    }
    
    private var emptyStateTitle: String {
        if hasSearchText {
            return mode == .launch ? "No applications found" : "No running apps found"
        } else {
            return mode == .launch ? "Start typing to search" : "Type after /k to search apps"
        }
    }
    
    private func getHelpText(for mode: LauncherMode) -> [String] {
        switch mode {
        case .launch:
            return LaunchCommandSuggestionProvider.getHelpText()
        case .kill:
            return KillCommandSuggestionProvider.getHelpText()
        case .search:
            return SearchCommandSuggestionProvider.getHelpText()
        case .web:
            return WebCommandSuggestionProvider.getHelpText()
        case .terminal:
            return TerminalCommandSuggestionProvider.getHelpText()
        case .file:
            return FileCommandSuggestionProvider.getHelpText()
        }
    }
}
