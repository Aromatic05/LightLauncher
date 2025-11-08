import Foundation

/// 字符串匹配工具类
/// 提供各种字符串比较和距离计算算法
struct StringMatcher {

    /// 计算两个字符串之间的编辑距离（Levenshtein距离）
    /// - Parameters:
    ///   - s1: 第一个字符串
    ///   - s2: 第二个字符串
    /// - Returns: 编辑距离值
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
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
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,  // deletion
                        matrix[i][j - 1] + 1,  // insertion
                        matrix[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }

        return matrix[s1Count][s2Count]
    }

    /// 计算单词开头匹配分数
    /// 检查查询字符串是否匹配文本中任何单词的开头
    static func calculateWordStartMatch(text: String, query: String) -> Double? {
        // split by non-alphanumerics and CamelCase boundaries
        let words = splitWords(text).filter { !$0.isEmpty }

        var bestScore: Double = 0
        var foundMatch = false

        for (wordIndex, word) in words.enumerated() {
            if word.lowercased().hasPrefix(query.lowercased()) {
                foundMatch = true

                // 基础分数：匹配程度
                let matchCompleteness = Double(query.count) / Double(word.count)
                var score = matchCompleteness * 100.0

                // 位置奖励：越靠前的单词分数越高
                let positionBonus = max(0, 50.0 - Double(wordIndex) * 10.0)
                score += positionBonus

                // 单词长度奖励：匹配较短的单词获得更高分数
                let lengthBonus = max(0, 30.0 - Double(word.count) * 2.0)
                score += lengthBonus

                // 完全匹配单词获得额外奖励
                if query.lowercased() == word.lowercased() {
                    score += 50.0
                }

                bestScore = max(bestScore, score)
            }
        }

        return foundMatch ? bestScore : nil
    }

    /// 将文本拆分为单词，支持 CamelCase 拆分和非字母数字分隔符
    private static func splitWords(_ text: String) -> [String] {
        let tokens = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter {
            !$0.isEmpty
        }
        var words: [String] = []

        for token in tokens {
            var current = ""
            let chars = Array(token)
            for (i, ch) in chars.enumerated() {
                if i > 0 {
                    let prev = chars[i - 1]
                    if prev.isLowercase && ch.isUppercase {
                        if !current.isEmpty { words.append(current) }
                        current = String(ch)
                        continue
                    }
                    if prev.isUppercase && ch.isLowercase {
                        if current.allSatisfy({ $0.isUppercase }) && current.count > 1 {
                            let last = current.removeLast()
                            words.append(current)
                            current = String(last) + String(ch)
                            continue
                        }
                    }
                }
                current.append(ch)
            }
            if !current.isEmpty { words.append(current) }
        }

        return words
    }

    /// 计算子序列匹配分数
    /// 检查查询字符串的字符是否按顺序出现在文本中
    static func calculateSubsequenceMatch(text: String, query: String) -> Double? {
        let textChars = Array(text.lowercased())
        let queryChars = Array(query.lowercased())

        var textIndex = 0
        var queryIndex = 0
        var matchPositions: [Int] = []

        // 寻找子序列匹配
        while textIndex < textChars.count && queryIndex < queryChars.count {
            if textChars[textIndex] == queryChars[queryIndex] {
                matchPositions.append(textIndex)
                queryIndex += 1
            }
            textIndex += 1
        }

        // 如果没有完全匹配所有查询字符
        guard queryIndex == queryChars.count else { return nil }

        // 计算分数：考虑匹配密度和位置
        let totalSpan = matchPositions.last! - matchPositions.first! + 1
        let density = Double(queryChars.count) / Double(totalSpan)
        let positionBonus = 1.0 - Double(matchPositions.first!) / Double(textChars.count)

        return (density * 50.0) + (positionBonus * 30.0)
    }

    /// 计算模糊匹配分数
    /// 使用编辑距离算法计算字符串相似度
    static func calculateFuzzyMatch(text: String, query: String) -> Double? {
        let distance = levenshteinDistance(text.lowercased(), query.lowercased())
        let maxLength = max(text.count, query.count)

        // 如果编辑距离太大，认为不匹配
        guard distance <= maxLength / 2 else { return nil }

        let similarity = 1.0 - Double(distance) / Double(maxLength)
        return similarity * 80.0
    }
}
