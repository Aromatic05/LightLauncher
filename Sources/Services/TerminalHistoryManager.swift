import Foundation
import AppKit
import SwiftUI

// MARK: - 终端命令历史项
struct TerminalHistoryItem: Codable, Identifiable, Hashable, @preconcurrency DisplayableItem {
    let id: UUID
    let command: String
    let timestamp: Date
    var title: String { command }
    var subtitle: String? { "终端命令" }
    var icon: NSImage? { nil }

    @MainActor
    func makeRowView(isSelected: Bool, index: Int) -> AnyView {
        if index == 0 {
            return AnyView(TerminalCurrentCommandRowView(command: command, isSelected: isSelected))
        } else {
            return AnyView(TerminalHistoryRowView(item: self, isSelected: isSelected, index: index, onDelete: {}))
        }
    }
    
    init(command: String) {
        self.id = UUID()
        self.command = command
        self.timestamp = Date()
    }
}

// MARK: - 终端命令历史管理器
@MainActor
class TerminalHistoryManager: ObservableObject {
    static let shared = TerminalHistoryManager()
    
    @Published private(set) var commandHistory: [TerminalHistoryItem] = []
    private let maxHistoryCount = 50 // 最多保存50条历史记录
    
    private var historyFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("LightLauncher").appendingPathComponent("terminal_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    // MARK: - 公共方法
    
    /// 添加命令记录
    func addCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }
        
        // 移除相同的历史记录（如果存在）
        commandHistory.removeAll { $0.command.lowercased() == trimmedCommand.lowercased() }
        
        // 添加新记录到开头
        let newItem = TerminalHistoryItem(command: trimmedCommand)
        commandHistory.insert(newItem, at: 0)
        
        // 限制历史记录数量
        if commandHistory.count > maxHistoryCount {
            commandHistory = Array(commandHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// 获取匹配的命令历史
    func getMatchingHistory(for command: String, limit: Int = 10) -> [TerminalHistoryItem] {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if trimmedCommand.isEmpty {
            return Array(commandHistory.prefix(limit))
        }
        
        return commandHistory
            .filter { $0.command.lowercased().contains(trimmedCommand) }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 清除所有命令历史
    func clearHistory() {
        commandHistory.removeAll()
        saveHistory()
    }
    
    /// 删除特定的命令记录
    func removeCommand(item: TerminalHistoryItem) {
        commandHistory.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    // MARK: - 私有方法
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            commandHistory = try JSONDecoder().decode([TerminalHistoryItem].self, from: data)
        } catch {
            // 如果加载失败，使用空数组
            commandHistory = []
            print("Failed to load terminal history: \(error)")
        }
    }
    
    private func saveHistory() {
        do {
            // 确保目录存在
            let directory = historyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(commandHistory)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save terminal history: \(error)")
        }
    }
}
