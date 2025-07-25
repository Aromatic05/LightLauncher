import Foundation

/// 应用搜索匹配器 - 负责计算应用与查询字符串的匹配分数
struct AppSearchMatcher {
    
    /// 通用搜索匹配结果结构
    struct ItemMatch {
        let item: any DisplayableItem
        let score: Double
        let matchType: AppMatch.MatchType
    }

    /// 计算 DisplayableItem 与查询字符串的匹配结果
    /// - Parameters:
    ///   - item: 可显示项目（应用或设置项）
    ///   - query: 查询字符串
    ///   - usageCount: 使用次数统计
    ///   - commonAbbreviations: 常用缩写配置 [缩写: [完整词汇列表]]
    /// - Returns: 匹配结果，如果不匹配则返回 nil
    static func calculateMatch(
        for item: any DisplayableItem,
        query: String,
        usageCount: [String: Int],
        commonAbbreviations: [String: [String]]
    ) -> ItemMatch? {
        let name = item.title.lowercased()
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return nil }

        // AppInfo 专用匹配
        if let app = item as? AppInfo {
            // 检查自定义缩写配置
            if let abbreviationWords = commonAbbreviations[searchQuery] {
                var bestAbbrevMatch: (score: Double, matchType: AppMatch.MatchType)?
                for word in abbreviationWords {
                    if let match = calculateDirectMatch(appName: name, query: word.lowercased()) {
                        if bestAbbrevMatch == nil || match.score > bestAbbrevMatch!.score {
                            bestAbbrevMatch = match
                        }
                    }
                    if name.contains(word.lowercased()) {
                        let containsScore = 150.0 + (1.0 - Double(word.count) / Double(name.count)) * 50.0
                        if bestAbbrevMatch == nil || containsScore > bestAbbrevMatch!.score {
                            bestAbbrevMatch = (score: containsScore, matchType: .contains)
                        }
                    }
                }
                if let match = bestAbbrevMatch {
                    let boostedScore = match.score + 500.0
                    let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                    return ItemMatch(item: item, score: boostedScore + usageBonus, matchType: match.matchType)
                }
            }
            // 直接匹配
            if let match = calculateDirectMatch(appName: name, query: searchQuery) {
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                let finalScore = match.score + usageBonus
                return ItemMatch(item: item, score: finalScore, matchType: match.matchType)
            }
            // 拼音匹配
            if let pinyinMatch = PinyinMatcher.calculatePinyinMatch(appName: name, query: searchQuery) {
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                let finalScore = pinyinMatch.score + usageBonus
                return ItemMatch(item: item, score: finalScore, matchType: pinyinMatch.matchType)
            }
            return nil
        }

        // PreferencePaneItem 或其他 DisplayableItem
        // 1. 完全匹配开头
        if name.hasPrefix(searchQuery) {
            let completeness = Double(searchQuery.count) / Double(name.count)
            let score = 1000.0 + completeness * 200.0
            return ItemMatch(item: item, score: score, matchType: .exactStart)
        }
        // 2. 包含匹配
        if name.contains(searchQuery) {
            let position = Double(name.distance(from: name.startIndex, to: name.range(of: searchQuery)!.lowerBound))
            let positionScore = max(0, 100.0 - position * 2.0)
            return ItemMatch(item: item, score: positionScore + 200.0, matchType: .contains)
        }
        // 3. 子序列匹配（简单实现）
        if StringMatcher.calculateSubsequenceMatch(text: name, query: searchQuery) != nil {
            return ItemMatch(item: item, score: 300.0, matchType: .subsequence)
        }
        // 4. 模糊匹配（简单实现）
        if StringMatcher.calculateFuzzyMatch(text: name, query: searchQuery) != nil {
            return ItemMatch(item: item, score: 200.0, matchType: .fuzzy)
        }
        return nil
    }
    
    /// 计算直接匹配（英文匹配）
    private static func calculateDirectMatch(appName: String, query: String) -> (score: Double, matchType: AppMatch.MatchType)? {
        // 1. 完全匹配开头 - 最高优先级
        if appName.hasPrefix(query) {
            let completeness = Double(query.count) / Double(appName.count)
            let score = 1000.0 + completeness * 200.0 // 匹配长度越长分数越高
            return (score: score, matchType: .exactStart)
        }
        
        // 2. 首字母缩写匹配 (如 "vsc" 匹配 "Visual Studio Code")
        if let acronymScore = calculateAcronymMatch(appName: appName, query: query) {
            return (score: acronymScore + 900.0, matchType: .wordStart)
        }
        
        // 3. 单词开头匹配 (如 "vis" 匹配 "Visual Studio Code")
        if let wordStartScore = StringMatcher.calculateWordStartMatch(text: appName, query: query) {
            return (score: wordStartScore + 800.0, matchType: .wordStart)
        }
        
        // 4. 单词内部前缀匹配 (如 "studio" 匹配 "Visual Studio Code")
        if let wordInternalScore = calculateWordInternalMatch(appName: appName, query: query) {
            return (score: wordInternalScore + 700.0, matchType: .wordStart)
        }
        
        // 5. 子序列匹配
        if let subsequenceScore = StringMatcher.calculateSubsequenceMatch(text: appName, query: query) {
            return (score: subsequenceScore + 600.0, matchType: .subsequence)
        }
        
        // 6. 模糊匹配
        if let fuzzyScore = StringMatcher.calculateFuzzyMatch(text: appName, query: query) {
            return (score: fuzzyScore + 400.0, matchType: .fuzzy)
        }
        
        // 7. 包含匹配 - 最低优先级
        if appName.contains(query) {
            let position = Double(appName.distance(from: appName.startIndex, to: appName.range(of: query)!.lowerBound))
            let positionScore = max(0, 100.0 - position * 2.0) // 越靠前分数越高
            return (score: positionScore + 200.0, matchType: .contains)
        }
        
        return nil
    }
    
    /// 计算首字母缩写匹配分数 (如 "vsc" 匹配 "Visual Studio Code")
    private static func calculateAcronymMatch(appName: String, query: String) -> Double? {
        let words = appName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
        
        guard words.count >= query.count else { return nil }
        
        let queryChars = Array(query.lowercased())
        var score: Double = 0
        var matchedWords = 0
        
        // 检查是否每个查询字符都能匹配到对应单词的首字母
        for (index, char) in queryChars.enumerated() {
            if index < words.count {
                let word = words[index].lowercased()
                if !word.isEmpty && word.first == char {
                    matchedWords += 1
                    score += 50.0 // 每个匹配的首字母得分
                    
                    // 如果是连续完整匹配，给予额外奖励
                    if matchedWords == queryChars.count {
                        score += Double(queryChars.count) * 30.0
                    }
                } else {
                    // 尝试在后面的单词中找到匹配
                    var found = false
                    for laterIndex in (index + 1)..<min(words.count, index + 3) { // 只在接下来的2个单词中查找
                        let laterWord = words[laterIndex].lowercased()
                        if !laterWord.isEmpty && laterWord.first == char {
                            matchedWords += 1
                            score += 30.0 // 非连续匹配得分较低
                            found = true
                            break
                        }
                    }
                    if !found {
                        break // 如果找不到匹配，停止匹配
                    }
                }
            }
        }
        
        // 只有当匹配比例足够高时才返回分数
        let matchRatio = Double(matchedWords) / Double(queryChars.count)
        return matchRatio >= 0.8 ? score : nil
    }
    
    /// 计算单词内部匹配分数 (如 "studio" 匹配 "Visual Studio Code")
    private static func calculateWordInternalMatch(appName: String, query: String) -> Double? {
        let words = appName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
        
        for (index, word) in words.enumerated() {
            if word.lowercased().hasPrefix(query.lowercased()) {
                // 根据单词在应用名中的位置给分
                let positionBonus = max(0, 100.0 - Double(index) * 20.0)
                // 根据匹配长度给分
                let lengthScore = Double(query.count) / Double(word.count) * 100.0
                return positionBonus + lengthScore
            }
        }
        
        return nil
    }
    
    /// 计算使用频率加分
    private static func calculateUsageBonus(appName: String, usageCount: [String: Int]) -> Double {
        let usage = usageCount[appName, default: 0]
        if usage == 0 { return 0.0 }
        
        // 使用对数函数，避免过度偏向高频应用
        return min(30.0, log(Double(usage) + 1) * 10.0)
    }
}
