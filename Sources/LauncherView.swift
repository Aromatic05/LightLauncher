import SwiftUI
import AppKit
import Combine

final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    weak var viewModel: LauncherViewModel?
    private var eventMonitor: Any?
    
    private init() {}
    
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard let viewModel = viewModel else { return event }
        
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        let characters = event.characters
        
        DispatchQueue.main.async {
            switch keyCode {
            case 126: // Up Arrow
                viewModel.moveSelectionUp()
            case 125: // Down Arrow
                viewModel.moveSelectionDown()
            case 36, 76: // Enter, Numpad Enter
                if viewModel.launchSelectedApp() {
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                }
            case 53: // Escape
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            default:
                // Handle numeric shortcuts only if no modifier keys are pressed
                if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                   let chars = characters,
                   let number = Int(chars),
                   (1...6).contains(number) {
                    if viewModel.selectAppByNumber(number) {
                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                    }
                }
            }
        }
        
        switch keyCode {
        case 126, 125, 36, 76, 53: // Navigation keys we want to consume
            return nil
        default:
            // Handle numeric shortcuts
            if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
               let chars = characters,
               let number = Int(chars),
               (1...6).contains(number) {
                return nil // Consume numeric shortcuts
            }
            return event // Let other keys pass through
        }
    }
}

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header Area
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Light Launcher")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Search Box
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Search applications...", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                        .focused($isSearchFieldFocused)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false) // 阻止按钮获取焦点
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
            }
            .background(
                Rectangle()
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            
            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            // Results List
            if viewModel.hasResults {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element) { index, app in
                                AppRowView(
                                    app: app,
                                    isSelected: index == viewModel.selectedIndex,
                                    index: index
                                )
                                .id(index)
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                    if viewModel.launchSelectedApp() {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                                .focusable(false) // 阻止行获取焦点
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focusable(false) // 阻止容器获取焦点
                    }
                    .focusable(false) // 阻止滚动视图获取焦点
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else if !viewModel.searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No applications found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Try a different search term")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor.opacity(0.7))
                    
                    Text("Start typing to search")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 4) {
                        Text("Press ⌥Space to open launcher")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Text("Use ↑↓ arrows or numbers 1-6 to select")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
        .frame(width: 700, height: 500)
        .background(
            Color(NSColor.windowBackgroundColor).opacity(0.95)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.startMonitoring()
            // 强制焦点到搜索框
            isSearchFieldFocused = true
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
        // 监听焦点变化，确保焦点始终在搜索框
        .onChange(of: isSearchFieldFocused) { focused in
            if !focused {
                // 如果焦点丢失，立即重新获取
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
    }
}

struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Number label
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 24, height: 24)
                
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "app")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }
            
            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("Application")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                    ? LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Notification names
extension Notification.Name {
    static let hideWindow = Notification.Name("hideWindow")
}
