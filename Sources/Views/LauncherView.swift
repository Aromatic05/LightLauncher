import SwiftUI
import AppKit
import Combine

final class KeyboardEventHandler: @unchecked Sendable {
    static let shared = KeyboardEventHandler()
    weak var viewModel: LauncherViewModel?
    private var eventMonitor: Any?
    private var currentMode: LauncherMode = .launch
    
    private init() {}
    
    func updateMode(_ mode: LauncherMode) {
        currentMode = mode
    }
    
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let viewModel = self.viewModel else { return event }
            
            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
            let characters = event.characters
            
            // 预先检查是否是数字键
            let isNumericKey = modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty &&
                              characters != nil &&
                              Int(characters!) != nil &&
                              (1...6).contains(Int(characters!)!)
            
            // 如果是数字键且在web/search/terminal模式下，直接返回事件让它通过
            if isNumericKey && (self.currentMode == .web || self.currentMode == .search || self.currentMode == .terminal) {
                return event
            }
            
            DispatchQueue.main.async {
                switch keyCode {
                case 126: // Up Arrow
                    viewModel.moveSelectionUp()
                case 125: // Down Arrow
                    viewModel.moveSelectionDown()
                case 36, 76: // Enter, Numpad Enter
                    if viewModel.executeSelectedAction() {
                        // 在kill模式下不隐藏窗口
                        if viewModel.mode != .kill {
                            NotificationCenter.default.post(name: .hideWindow, object: nil)
                        }
                    }
                case 53: // Escape
                    NotificationCenter.default.post(name: .hideWindow, object: nil)
                default:
                    // Handle numeric shortcuts only if no modifier keys are pressed and not in web mode
                    if modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                       let chars = characters,
                       let number = Int(chars),
                       (1...6).contains(number),
                       self.currentMode != .web { // 在web模式下不处理数字快捷键
                        if viewModel.selectAppByNumber(number) {
                            // 在kill模式下不隐藏窗口
                            if viewModel.mode != .kill {
                                NotificationCenter.default.post(name: .hideWindow, object: nil)
                            }
                        }
                    }
                }
            }
            
            switch keyCode {
            case 126, 125, 36, 76, 53: // Navigation keys we want to consume
                return nil
            default:
                // Handle numeric shortcuts - 如果是数字键且不在web模式下，消费事件
                if isNumericKey && self.currentMode != .web {
                    return nil // Consume numeric shortcuts
                }
                return event // Let other keys pass through
            }
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            LauncherHeaderView(mode: viewModel.mode)
            
            // Search Box
            SearchBoxView(
                searchText: $viewModel.searchText,
                mode: viewModel.mode,
                onClear: {
                    viewModel.clearSearch()
                }
            )
            
            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            // Command Suggestions
            if viewModel.showCommandSuggestions {
                CommandSuggestionsView(commands: viewModel.commandSuggestions)
            }
            
            // Content
            if viewModel.showCommandSuggestions {
                // 当显示命令建议时，不显示其他内容
                Spacer()
            } else {
                switch viewModel.mode {
                case .launch:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            mode: viewModel.mode,
                            hasSearchText: !viewModel.searchText.isEmpty
                        )
                    }
                case .kill:
                    if viewModel.hasResults {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        EmptyStateView(
                            mode: viewModel.mode,
                            hasSearchText: !viewModel.searchText.isEmpty
                        )
                    }
                case .web:
                    if viewModel.hasResults || !viewModel.browserItems.isEmpty {
                        ResultsListView(viewModel: viewModel)
                    } else {
                        CommandInputView(mode: viewModel.mode, searchText: viewModel.searchText)
                    }
                case .search:
                    // 搜索模式总是显示搜索历史视图（包含当前输入项）
                    SearchHistoryView(viewModel: viewModel)
                case .terminal:
                    // 终端模式显示输入提示界面
                    CommandInputView(mode: viewModel.mode, searchText: viewModel.searchText)
                }
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
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = nil
        }
        .onChange(of: viewModel.mode) { newMode in
            KeyboardEventHandler.shared.updateMode(newMode)
        }
    }
}

struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    if viewModel.mode == .launch {
                        ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element) { index, app in
                            AppRowView(
                                app: app,
                                isSelected: index == viewModel.selectedIndex,
                                index: index,
                                mode: .launch
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    // 在kill模式下不隐藏窗口
                                    if viewModel.mode != .kill {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                            }
                            .focusable(false)
                        }
                    } else if viewModel.mode == .web {
                        // 在web模式下首先显示当前输入项
                        let cleanWebText = extractCleanWebText()
                        WebCurrentInputView(
                            input: cleanWebText.isEmpty ? "..." : cleanWebText,
                            isSelected: 0 == viewModel.selectedIndex
                        )
                        .id(0)
                        .onTapGesture {
                            viewModel.selectedIndex = 0
                            if viewModel.executeSelectedAction() {
                                NotificationCenter.default.post(name: .hideWindow, object: nil)
                            }
                        }
                        .focusable(false)
                        
                        // 然后显示浏览器历史项目
                        ForEach(Array(viewModel.browserItems.enumerated()), id: \.element) { index, item in
                            let displayIndex = index + 1 // 因为当前输入项占用了索引0
                            BrowserItemRowView(
                                item: item,
                                isSelected: displayIndex == viewModel.selectedIndex,
                                index: index
                            )
                            .id(displayIndex)
                            .onTapGesture {
                                viewModel.selectedIndex = displayIndex
                                if viewModel.executeSelectedAction() {
                                    // 在kill模式下不隐藏窗口
                                    if viewModel.mode != .kill {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                            }
                            .focusable(false)
                        }
                    } else {
                        ForEach(Array(viewModel.runningApps.enumerated()), id: \.element) { index, app in
                            RunningAppRowView(
                                app: app,
                                isSelected: index == viewModel.selectedIndex,
                                index: index
                            )
                            .id(index)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                if viewModel.executeSelectedAction() {
                                    // 在kill模式下不隐藏窗口
                                    if viewModel.mode != .kill {
                                        NotificationCenter.default.post(name: .hideWindow, object: nil)
                                    }
                                }
                            }
                            .focusable(false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focusable(false)
            }
            .focusable(false)
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func extractCleanWebText() -> String {
        let prefix = "/w "
        if viewModel.searchText.hasPrefix(prefix) {
            return String(viewModel.searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Command Suggestions View
struct CommandSuggestionsView: View {
    let commands: [LauncherCommand]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "command")
                    .foregroundColor(.blue)
                Text("可用命令")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            VStack(spacing: 8) {
                ForEach(commands, id: \.trigger) { command in
                    CommandSuggestionRow(command: command)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommandSuggestionRow: View {
    let command: LauncherCommand
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: command.mode.iconName)
                .foregroundColor(command.mode == .kill ? .red : .blue)
                .frame(width: 20, height: 20)
            
            // 命令信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(command.trigger)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Text(command.mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态指示器
            if command.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
    }
}

// MARK: - Command Input View
struct CommandInputView: View {
    let mode: LauncherMode
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 模式图标和标题
            VStack(spacing: 16) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(iconColor)
                
                Text(mode.displayName)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // 输入提示
            VStack(spacing: 12) {
                Text(inputPrompt)
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
                ForEach(helpText, id: \.self) { text in
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
    
    private var iconColor: Color {
        switch mode {
        case .search:
            return .blue
        case .web:
            return .green
        case .terminal:
            return .orange
        default:
            return .primary
        }
    }
    
    private var inputPrompt: String {
        switch mode {
        case .search:
            return "输入搜索关键词，按回车搜索网页"
        case .web:
            return "输入网址或网站名称，按回车打开"
        case .terminal:
            return "输入终端命令，按回车执行"
        default:
            return "请输入内容"
        }
    }
    
    private var helpText: [String] {
        switch mode {
        case .search:
            return [
                "支持任意关键词搜索",
                "将使用默认搜索引擎",
                "删除 /s 前缀返回启动模式"
            ]
        case .web:
            return [
                "支持完整 URL 或域名",
                "自动添加 https:// 前缀",
                "删除 /w 前缀返回启动模式"
            ]
        case .terminal:
            return [
                "在终端应用中执行命令",
                "支持 Terminal 和 iTerm2",
                "删除 /t 前缀返回启动模式"
            ]
        default:
            return []
        }
    }
    
    private func extractCleanText() -> String {
        let prefix = "/\(mode.rawValue.first ?? "x") "
        if searchText.hasPrefix(prefix) {
            return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 搜索历史视图
struct SearchHistoryView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // 历史记录标题
                    HStack {
                        Text("搜索历史")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !viewModel.searchHistory.isEmpty {
                            Button("清空") {
                                viewModel.clearSearchHistory()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 在搜索模式下首先显示当前输入项
                    let cleanSearchText = extractCleanSearchText()
                    SearchCurrentQueryView(
                        query: cleanSearchText.isEmpty ? "..." : cleanSearchText,
                        isSelected: 0 == viewModel.selectedIndex
                    )
                    .id(0)
                    .onTapGesture {
                        viewModel.selectedIndex = 0
                        if viewModel.executeSelectedAction() {
                            NotificationCenter.default.post(name: .hideWindow, object: nil)
                        }
                    }
                    
                    // 然后显示历史记录列表
                    ForEach(Array(viewModel.searchHistory.prefix(10).enumerated()), id: \.element) { index, item in
                        let displayIndex = index + 1 // 因为当前输入项占用了索引0
                        SearchHistoryRowView(
                            item: item,
                            isSelected: displayIndex == viewModel.selectedIndex,
                            index: index + 1, // 显示序号从1开始
                            onDelete: {
                                viewModel.removeSearchHistoryItem(item)
                            }
                        )
                        .id(displayIndex)
                        .onTapGesture {
                            viewModel.selectedIndex = displayIndex
                            if viewModel.executeSelectedAction() {
                                NotificationCenter.default.post(name: .hideWindow, object: nil)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func extractCleanSearchText() -> String {
        let prefix = "/s "
        if viewModel.searchText.hasPrefix(prefix) {
            return String(viewModel.searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func hasMatchingHistory(_ query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return viewModel.searchHistory.contains { 
            $0.query.lowercased().contains(query.lowercased())
        }
    }
}

// MARK: - 搜索历史行视图
struct SearchHistoryRowView: View {
    let item: SearchHistoryItem
    let isSelected: Bool
    let index: Int
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 序号
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            // 搜索引擎图标
            Image(systemName: searchEngineIcon)
                .font(.system(size: 16))
                .foregroundColor(searchEngineColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                // 搜索查询
                Text(item.query)
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                // 时间和搜索引擎
                HStack(spacing: 8) {
                    Text(formatTime(item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.searchEngine.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 删除按钮
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var searchEngineIcon: String {
        switch item.searchEngine.lowercased() {
        case "google":
            return "globe"
        case "baidu":
            return "globe.asia.australia"
        case "bing":
            return "globe.americas"
        default:
            return "magnifyingglass"
        }
    }
    
    private var searchEngineColor: Color {
        switch item.searchEngine.lowercased() {
        case "google":
            return .blue
        case "baidu":
            return .red
        case "bing":
            return .green
        default:
            return .secondary
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 当前搜索查询视图
struct SearchCurrentQueryView: View {
    let query: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("搜索: \(query)")
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text("按回车执行搜索")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "return")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Web当前输入视图
struct WebCurrentInputView: View {
    let input: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .font(.caption)
                .foregroundColor(.clear)
                .frame(width: 20, alignment: .trailing)
            
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("打开: \(input)")
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text("按回车打开网页")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "return")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.green.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// Notification names
extension Notification.Name {
    static let hideWindow = Notification.Name("hideWindow")
}
