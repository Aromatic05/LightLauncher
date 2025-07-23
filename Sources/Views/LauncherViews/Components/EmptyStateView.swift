import SwiftUI

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
            return mode == .launch ? "magnifyingglass" : (mode == .clip ? "doc.on.clipboard" : "xmark.circle")
        } else {
            return mode == .launch ? "app.badge" : (mode == .clip ? "doc.on.clipboard" : "xmark.circle")
        }
    }
    
    private var emptyStateColor: Color {
        if hasSearchText {
            return .secondary.opacity(0.5)
        } else {
            if mode == .launch {
                return .accentColor.opacity(0.7)
            } else if mode == .clip {
                return .accentColor.opacity(0.7)
            } else {
                return .red.opacity(0.7)
            }
        }
    }
    
    private var emptyStateTitle: String {
        if hasSearchText {
            if mode == .launch {
                return "No applications found"
            } else if mode == .clip {
                return "No clipboard history found"
            } else {
                return "No running apps found"
            }
        } else {
            if mode == .launch {
                return "Start typing to search"
            } else if mode == .clip {
                return "No clipboard history yet"
            } else {
                return "Type after /k to search apps"
            }
        }
    }
    
    private func getHelpText(for mode: LauncherMode) -> [String] {
        LauncherViewModel.shared.activeController?.getHelpText() ?? []
    }
}