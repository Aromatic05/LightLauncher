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
    let originalName = item.title
    let name = originalName.lowercased()
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return nil }

        // AppInfo 专用匹配
        if let app = item as? AppInfo {
            // 优先级调整说明（实现顺序按优先级从高到低）:
            // 1) 前缀匹配 或 commonAbbreviations 的“完整缩写匹配”
            // 2) 多单词首字母匹配 (acronym) 或 commonAbbreviations 的部分匹配
            // 3) 多单词部分前缀匹配
            // 4) 内部连续子串匹配 (contains)
            // 5) 非连续子序列匹配 (subsequence)
            // 6) 模糊匹配

            // 1. 前缀匹配（最高优先级）
            if name.hasPrefix(searchQuery) {
                let completeness = Double(searchQuery.count) / Double(name.count)
                let score = 1200.0 + completeness * 200.0
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: score + usageBonus, matchType: .exactStart)
            }

            // 1b. commonAbbreviations 的“完整缩写匹配”视为与前缀匹配相同的优先级
            if let abbreviationWords = commonAbbreviations[searchQuery] {
                for word in abbreviationWords {
                    let w = word.lowercased()
                    // 如果应用名等于缩写映射的词、或以该词为单词开头、或包含该词，则视为完整缩写匹配
                    if name == w || name.hasPrefix(w) || name.contains(" " + w) || name.contains(w) {
                        let score = 1200.0 + 100.0
                        let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                        return ItemMatch(item: item, score: score + usageBonus, matchType: .contains)
                    }
                }
            }

            // 2. 多单词首字母匹配 (acronym)
            if let acronymScore = calculateAcronymMatch(appName: originalName, query: searchQuery) {
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: acronymScore + 1000.0 + usageBonus, matchType: .wordStart)
            }

            // 2b. commonAbbreviations 的部分匹配：尝试把映射的词作为查询去匹配，分数略低于 acronym
            if let abbreviationWords = commonAbbreviations[searchQuery] {
                var bestPartial: Double = 0
                for word in abbreviationWords {
                    if let m = calculateDirectMatch(appName: name, originalAppName: originalName, query: word.lowercased()) {
                        bestPartial = max(bestPartial, m.score)
                    }
                    if name.contains(word.lowercased()) {
                        // 给一个稳定的基础分数以保证优先级在 wordStart 之后
                        let containsScore = 550.0 + (1.0 - Double(word.count) / Double(name.count)) * 50.0
                        bestPartial = max(bestPartial, containsScore)
                    }
                }
                if bestPartial > 0 {
                    let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                    return ItemMatch(item: item, score: bestPartial + 900.0 + usageBonus, matchType: .contains)
                }
            }

            // 3. 多单词部分前缀匹配 与 拼音匹配 放在同一优先级，比较后返回更高分
            let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
            let wordStartScoreOpt = StringMatcher.calculateWordStartMatch(text: name, query: searchQuery)
            let pinyinMatchOpt = PinyinMatcher.calculatePinyinMatch(appName: name, query: searchQuery)

            if wordStartScoreOpt != nil || pinyinMatchOpt != nil {
                var bestScore: Double = 0
                var bestType: AppMatch.MatchType = .wordStart

                if let ws = wordStartScoreOpt {
                    bestScore = ws + 800.0
                    bestType = .wordStart
                }

                if let p = pinyinMatchOpt {
                    let pScore = p.score + 800.0
                    if pScore > bestScore {
                        bestScore = pScore
                        bestType = p.matchType
                    }
                }

                return ItemMatch(item: item, score: bestScore + usageBonus, matchType: bestType)
            }

            // 4. 单词内部前缀匹配
            if let wordInternalScore = calculateWordInternalMatch(appName: originalName, query: searchQuery) {
                let usageBonusInternal = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: wordInternalScore + 700.0 + usageBonusInternal, matchType: .wordStart)
            }

            // 5. 内部连续子串匹配 (contains) - 优先于非连续子序列
            if name.contains(searchQuery) {
                let position = Double(
                    name.distance(from: name.startIndex, to: name.range(of: searchQuery)!.lowerBound))
                let positionScore = max(0, 150.0 - position * 2.0)
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: positionScore + 600.0 + usageBonus, matchType: .contains)
            }

            // 6. 非连续子序列匹配
            if let subsequenceScore = StringMatcher.calculateSubsequenceMatch(text: name, query: searchQuery) {
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: subsequenceScore + 500.0 + usageBonus, matchType: .subsequence)
            }

            // (已在上方与多单词前缀比较并处理过拼音匹配)

            // 8. 模糊匹配（最低优先级）
            if let fuzzyScore = StringMatcher.calculateFuzzyMatch(text: name, query: searchQuery) {
                let usageBonus = calculateUsageBonus(appName: app.name, usageCount: usageCount)
                return ItemMatch(item: item, score: fuzzyScore + 300.0 + usageBonus, matchType: .fuzzy)
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
            let position = Double(
                name.distance(from: name.startIndex, to: name.range(of: searchQuery)!.lowerBound))
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
    private static func calculateDirectMatch(appName: String, originalAppName: String, query: String) -> (
        score: Double, matchType: AppMatch.MatchType
    )? {
        // 1. 完全匹配开头 - 最高优先级
        if appName.hasPrefix(query) {
            let completeness = Double(query.count) / Double(appName.count)
            let score = 1000.0 + completeness * 200.0  // 匹配长度越长分数越高
            return (score: score, matchType: .exactStart)
        }

        // 2. 首字母缩写匹配 (如 "vsc" 匹配 "Visual Studio Code")
        if let acronymScore = calculateAcronymMatch(appName: originalAppName, query: query) {
            return (score: acronymScore + 900.0, matchType: .wordStart)
        }

        // 3. 单词开头匹配 (如 "vis" 匹配 "Visual Studio Code")
        if let wordStartScore = StringMatcher.calculateWordStartMatch(text: appName, query: query) {
            return (score: wordStartScore + 800.0, matchType: .wordStart)
        }

        // 4. 单词内部前缀匹配 (如 "studio" 匹配 "Visual Studio Code")
        if let wordInternalScore = calculateWordInternalMatch(appName: originalAppName, query: query) {
            return (score: wordInternalScore + 700.0, matchType: .wordStart)
        }

        // 5. 包含匹配（连续子串） - 优先于非连续子序列
        if appName.contains(query) {
            let position = Double(
                appName.distance(from: appName.startIndex, to: appName.range(of: query)!.lowerBound)
            )
            let positionScore = max(0, 150.0 - position * 2.0)  // 越靠前分数越高
            return (score: positionScore + 600.0, matchType: .contains)
        }

        // 6. 非连续子序列匹配
        if let subsequenceScore = StringMatcher.calculateSubsequenceMatch(
            text: appName, query: query)
        {
            return (score: subsequenceScore + 500.0, matchType: .subsequence)
        }

        // 7. 模糊匹配
        if let fuzzyScore = StringMatcher.calculateFuzzyMatch(text: appName, query: query) {
            return (score: fuzzyScore + 300.0, matchType: .fuzzy)
        }

        return nil
    }

    /// 计算首字母缩写匹配分数 (如 "vsc" 匹配 "Visual Studio Code")
    private static func calculateAcronymMatch(appName: String, query: String) -> Double? {
        // split words, honoring CamelCase and non-alphanumerics
        let words = splitWords(appName).filter { !$0.isEmpty }

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
                    score += 50.0  // 每个匹配的首字母得分

                    // 如果是连续完整匹配，给予额外奖励
                    if matchedWords == queryChars.count {
                        score += Double(queryChars.count) * 30.0
                    }
                } else {
                    // 尝试在后面的单词中找到匹配
                    var found = false
                    for laterIndex in (index + 1)..<min(words.count, index + 3) {  // 只在接下来的2个单词中查找
                        let laterWord = words[laterIndex].lowercased()
                        if !laterWord.isEmpty && laterWord.first == char {
                            matchedWords += 1
                            score += 30.0  // 非连续匹配得分较低
                            found = true
                            break
                        }
                    }
                    if !found {
                        break  // 如果找不到匹配，停止匹配
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
        let words = splitWords(appName).filter { !$0.isEmpty }

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

    /// 将文本拆分为单词，支持 CamelCase 拆分和非字母数字分隔符
    private static func splitWords(_ text: String) -> [String] {
        // 先按非字母数字分割
        let tokens = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        var words: [String] = []

        for token in tokens {
            var current = ""
            let chars = Array(token)
            for (i, ch) in chars.enumerated() {
                if i > 0 {
                    let prev = chars[i - 1]
                    // 如果从小写到大写，视为新单词边界 (e.g. PowerPoint -> Power Point)
                    if prev.isLowercase && ch.isUppercase {
                        if !current.isEmpty {
                            words.append(current)
                        }
                        current = String(ch)
                        continue
                    }
                    // 如果前为大写且当前为大写，继续累积 (支持缩写如 PDF)
                    // 如果前为大写且当前为小写，并且前面的序列长度>1，将前面的大写序列作为单词
                    if prev.isUppercase && ch.isLowercase {
                        // 如果 current 是全部大写且长度>1, split before last uppercase
                        if current.allSatisfy({ $0.isUppercase }) && current.count > 1 {
                            // move last char to new current
                            let last = current.removeLast()
                            words.append(current)
                            current = String(last) + String(ch)
                            continue
                        }
                    }
                }
                current.append(ch)
            }
            if !current.isEmpty {
                words.append(current)
            }
        }

        return words
    }

    /// 计算使用频率加分
    private static func calculateUsageBonus(appName: String, usageCount: [String: Int]) -> Double {
        let usage = usageCount[appName, default: 0]
        if usage == 0 { return 0.0 }

        // 使用对数函数，避免过度偏向高频应用
        return min(30.0, log(Double(usage) + 1) * 10.0)
    }
}
