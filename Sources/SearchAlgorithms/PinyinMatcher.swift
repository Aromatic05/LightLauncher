import Foundation

/// 拼音匹配工具类
/// 负责处理中文拼音首字母匹配
struct PinyinMatcher {
    
    /// 获取文本的拼音首字母
    /// - Parameter text: 输入文本（可包含中文和英文）
    /// - Returns: 拼音首字母字符串
    static func getPinyinInitials(from text: String) -> String {
        var result = ""
        
        for char in text {
            if char.isASCII {
                // 如果是英文字符，直接添加
                if char.isLetter {
                    result += String(char).lowercased()
                }
            } else {
                // 对于中文字符，使用 CFStringTransform 转换为拼音
                let mutableString = NSMutableString(string: String(char))
                if CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false) {
                    if CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false) {
                        let pinyin = String(mutableString).lowercased()
                        // 取第一个字母作为首字母
                        if let firstChar = pinyin.first, firstChar.isLetter {
                            result += String(firstChar)
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    /// 计算拼音匹配分数
    /// - Parameters:
    ///   - appName: 应用名称
    ///   - query: 查询字符串
    /// - Returns: 匹配结果，包含分数和匹配类型
    static func calculatePinyinMatch(appName: String, query: String) -> (score: Double, matchType: AppMatch.MatchType)? {
        let pinyinInitials = getPinyinInitials(from: appName)
        
        // 完全匹配拼音首字母
        if pinyinInitials.hasPrefix(query) {
            let score = 90.0 + (1.0 - Double(query.count) / Double(pinyinInitials.count)) * 30.0
            return (score: score, matchType: .exactStart)
        }
        
        // 检查是否包含查询字符串
        if pinyinInitials.contains(query) {
            let score = 70.0 + (1.0 - Double(query.count) / Double(pinyinInitials.count)) * 20.0
            return (score: score, matchType: .contains)
        }
        
        // 子序列匹配拼音首字母
        if let subsequenceScore = StringMatcher.calculateSubsequenceMatch(text: pinyinInitials, query: query) {
            return (score: subsequenceScore + 50.0, matchType: .subsequence)
        }
        
        return nil
    }
}
