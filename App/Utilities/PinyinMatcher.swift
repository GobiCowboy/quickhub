import Foundation

struct PinyinMatcher {
    /// 检查输入的 query 是否能匹配目标文字（支持原文字、全拼或首字母简拼）
    static func match(_ text: String, query: String) -> Bool {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        if cleanQuery.isEmpty { return true }
        
        let lowerText = text.lowercased()
        
        // 1. 直接包含（中文字符或已有的英文字符）
        if lowerText.contains(cleanQuery) {
            print("[PinyinMatch] Query: '\(cleanQuery)', Text: '\(text)' -> DIRECT MATCH")
            return true 
        }
        
        // 获取全拼和简拼
        let pinyinFull = convertToPinyin(text, stripSpaces: true)
        let initials = extractInitials(text)
        
        print("[PinyinMatch] Query: '\(cleanQuery)', Text: '\(text)', Pinyin: '\(pinyinFull)', Initials: '\(initials)'")
        
        // 2. 全拼包含匹配
        if pinyinFull.contains(cleanQuery) {
            print("[PinyinMatch] -> FULL PINYIN MATCH")
            return true
        }
        
        // 3. 简拼前缀匹配
        if initials.hasPrefix(cleanQuery) {
            print("[PinyinMatch] -> INITIALS PREFIX MATCH")
            return true
        }
        
        // 4. 增强：支持子序列匹配
        if isSubsequence(cleanQuery, in: initials) {
            print("[PinyinMatch] -> INITIALS SUBSEQUENCE MATCH")
            return true
        }

        return false
    }
    
    private static func isSubsequence(_ query: String, in text: String) -> Bool {
        if query.isEmpty { return true }
        var queryIdx = query.startIndex
        var textIdx = text.startIndex
        
        while queryIdx < query.endIndex && textIdx < text.endIndex {
            if query[queryIdx] == text[textIdx] {
                queryIdx = query.index(after: queryIdx)
            }
            textIdx = text.index(after: textIdx)
        }
        return queryIdx == query.endIndex
    }
    
    private static func convertToPinyin(_ text: String, stripSpaces: Bool) -> String {
        let mutableString = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let result = mutableString as String
        return stripSpaces ? result.lowercased().replacingOccurrences(of: " ", with: "") : result.lowercased()
    }
    
    private static func extractInitials(_ text: String) -> String {
        var initials = ""
        for char in text {
            let s = String(char)
            let ms = NSMutableString(string: s) as CFMutableString
            CFStringTransform(ms, nil, kCFStringTransformToLatin, false)
            CFStringTransform(ms, nil, kCFStringTransformStripDiacritics, false)
            if let firstChar = (ms as String).first {
                initials.append(firstChar.lowercased())
            }
        }
        return initials
    }
}
