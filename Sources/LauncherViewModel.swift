import Foundation
import Combine
import AppKit

// 应用匹配结果结构
struct AppMatch {
    let app: AppInfo
    let score: Double
    let matchType: MatchType
    
    enum MatchType {
        case exactStart      // 完全匹配开头
        case wordStart       // 单词开头匹配
        case subsequence     // 子序列匹配
        case fuzzy          // 模糊匹配
        case contains       // 包含匹配
    }
}

@MainActor
class LauncherViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var filteredApps: [AppInfo] = []
    
    private var allApps: [AppInfo] = []
    private let appScanner: AppScanner
    private var cancellables = Set<AnyCancellable>()
    
    // 使用频率统计
    private var appUsageCount: [String: Int] = [:]
    private let userDefaults = UserDefaults.standard
    
    init(appScanner: AppScanner) {
        self.appScanner = appScanner
        loadUsageData()
        
        // 监听 AppScanner 的应用列表
        appScanner.$applications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.allApps = apps
                // 初始加载时，显示最常用的前6个应用
                self?.filteredApps = self?.getMostUsedApps(from: apps, limit: 6) ?? []
                self?.selectedIndex = 0
            }
            .store(in: &cancellables)
        
        // 监听搜索文本的变化
        $searchText
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                self?.filterApps(searchText: text)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 使用频率管理
    
    private func loadUsageData() {
        if let data = userDefaults.object(forKey: "appUsageCount") as? [String: Int] {
            appUsageCount = data
        }
    }
    
    private func saveUsageData() {
        userDefaults.set(appUsageCount, forKey: "appUsageCount")
    }
    
    private func incrementUsage(for appName: String) {
        appUsageCount[appName, default: 0] += 1
        saveUsageData()
    }
    
    private func getMostUsedApps(from apps: [AppInfo], limit: Int) -> [AppInfo] {
        return apps
            .sorted { app1, app2 in
                let usage1 = appUsageCount[app1.name, default: 0]
                let usage2 = appUsageCount[app2.name, default: 0]
                if usage1 != usage2 {
                    return usage1 > usage2
                }
                return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - 智能搜索算法
    
    private func filterApps(searchText: String) {
        if searchText.isEmpty {
            filteredApps = getMostUsedApps(from: allApps, limit: 6)
        } else {
            let matches = allApps.compactMap { app in
                calculateMatch(for: app, query: searchText)
            }
            
            // 按评分排序并取前6个
            filteredApps = matches
                .sorted { $0.score > $1.score }
                .prefix(6)
                .map { $0.app }
        }
        // 每当列表更新时，重置选择
        selectedIndex = 0
    }
    
    private func calculateMatch(for app: AppInfo, query: String) -> AppMatch? {
        let appName = app.name.lowercased()
        let searchQuery = query.lowercased()
        
        guard !searchQuery.isEmpty else { return nil }
        
        var score: Double = 0
        var matchType: AppMatch.MatchType = .contains
        
        // 1. 完全匹配开头 (最高优先级)
        if appName.hasPrefix(searchQuery) {
            score = 1000 + Double(searchQuery.count) * 10
            matchType = .exactStart
        }
        // 2. 单词开头匹配 (如搜索 "vs" 匹配 "Visual Studio Code")
        else if let wordStartScore = calculateWordStartMatch(appName: appName, query: searchQuery) {
            score = 800 + wordStartScore
            matchType = .wordStart
        }
        // 3. 拼音首字母匹配 (如搜索 "wps" 匹配中文应用)
        else if let pinyinScore = calculatePinyinMatch(appName: app.name, query: searchQuery) {
            score = 750 + pinyinScore
            matchType = .wordStart
        }
        // 4. 子序列匹配 (如搜索 "vsc" 匹配 "Visual Studio Code")
        else if let subsequenceScore = calculateSubsequenceMatch(appName: appName, query: searchQuery) {
            score = 600 + subsequenceScore
            matchType = .subsequence
        }
        // 5. 模糊匹配 (允许一些字符错误)
        else if let fuzzyScore = calculateFuzzyMatch(appName: appName, query: searchQuery) {
            score = 400 + fuzzyScore
            matchType = .fuzzy
        }
        // 6. 简单包含匹配
        else if appName.contains(searchQuery) {
            score = 200 + Double(searchQuery.count) * 5
            matchType = .contains
        }
        else {
            return nil
        }
        
        // 添加使用频率权重 (增加权重影响)
        let usageCount = appUsageCount[app.name, default: 0]
        let usageBonus = Double(usageCount) * 15
        score += usageBonus
        
        // 添加应用名称长度权重 (较短的名称获得轻微优势)
        let lengthPenalty = Double(appName.count) * -0.3
        score += lengthPenalty
        
        // 添加查询匹配度权重 (查询越长，匹配越精确，给予更高分数)
        let queryLengthBonus = Double(searchQuery.count) * 2
        score += queryLengthBonus
        
        return AppMatch(app: app, score: score, matchType: matchType)
    }
    
    // 单词开头匹配算法
    private func calculateWordStartMatch(appName: String, query: String) -> Double? {
        let words = appName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
        
        let queryChars = Array(query)
        var queryIndex = 0
        var matchedWords = 0
        
        for word in words {
            if queryIndex < queryChars.count && word.lowercased().hasPrefix(String(queryChars[queryIndex])) {
                queryIndex += 1
                matchedWords += 1
                
                // 如果完全匹配了查询
                if queryIndex == queryChars.count {
                    return Double(matchedWords * 50) + Double(query.count * 10)
                }
            }
        }
        
        // 部分匹配也给一些分数
        return queryIndex > 0 ? Double(queryIndex * 20) : nil
    }
    
    // 子序列匹配算法
    private func calculateSubsequenceMatch(appName: String, query: String) -> Double? {
        let appChars = Array(appName)
        let queryChars = Array(query)
        
        var appIndex = 0
        var queryIndex = 0
        var score: Double = 0
        var consecutiveMatches = 0
        
        while appIndex < appChars.count && queryIndex < queryChars.count {
            if appChars[appIndex].lowercased() == String(queryChars[queryIndex]).lowercased() {
                queryIndex += 1
                consecutiveMatches += 1
                score += Double(consecutiveMatches) * 2 // 连续匹配加分
            } else {
                consecutiveMatches = 0
            }
            appIndex += 1
        }
        
        // 必须匹配所有查询字符
        return queryIndex == queryChars.count ? score : nil
    }
    
    // 模糊匹配算法 (允许少量错误)
    private func calculateFuzzyMatch(appName: String, query: String) -> Double? {
        let maxErrors = max(1, query.count / 3) // 允许最多1/3的字符错误
        
        let distance = levenshteinDistance(appName, query)
        
        if distance <= maxErrors {
            return Double(query.count * 10) - Double(distance * 5)
        }
        
        return nil
    }
    
    // 计算编辑距离
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                if s1Array[i-1] == s2Array[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,     // deletion
                        matrix[i][j-1] + 1,     // insertion
                        matrix[i-1][j-1] + 1    // substitution
                    )
                }
            }
        }
        
        return matrix[s1Count][s2Count]
    }
    
    func moveSelectionUp() {
        guard !filteredApps.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : filteredApps.count - 1
    }
    
    func moveSelectionDown() {
        guard !filteredApps.isEmpty else { return }
        selectedIndex = selectedIndex < filteredApps.count - 1 ? selectedIndex + 1 : 0
    }
    
    func launchSelectedApp() -> Bool {
        guard selectedIndex < filteredApps.count else { return false }
        let selectedApp = filteredApps[selectedIndex]
        
        let success = NSWorkspace.shared.open(selectedApp.url)
        
        if success {
            // 记录使用频率
            incrementUsage(for: selectedApp.name)
            clearSearch()
        }
        
        return success
    }
    
    func clearSearch() {
        searchText = ""
        selectedIndex = 0
    }
    
    var hasResults: Bool {
        !filteredApps.isEmpty
    }
    
    var selectedApp: AppInfo? {
        guard selectedIndex < filteredApps.count else { return nil }
        return filteredApps[selectedIndex]
    }
    
    func selectAppByNumber(_ number: Int) -> Bool {
        let index = number - 1 // 转换为0基础索引
        guard index >= 0 && index < filteredApps.count && index < 6 else { return false }
        selectedIndex = index
        
        let selectedApp = filteredApps[selectedIndex]
        let success = NSWorkspace.shared.open(selectedApp.url)
        
        if success {
            // 记录使用频率
            incrementUsage(for: selectedApp.name)
            clearSearch()
        }
        
        return success
    }
}
