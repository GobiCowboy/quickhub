import Foundation

struct PinyinMatcher {
    /// 检查输入的 query 是否能匹配目标文字（支持原文字、全拼或首字母简拼）
    static func match(_ text: String, query: String) -> Bool {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        if cleanQuery.isEmpty { return true }
        
        let lowerText = text.lowercased()
        
        // 1. 直接包含（中文字符或已有的英文字符）
        if lowerText.contains(cleanQuery) { return true }
        
        // 2. 转换为拼音全拼
        let mutableString = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let pinyin = (mutableString as String).lowercased().replacingOccurrences(of: " ", with: "")
        
        if pinyin.contains(cleanQuery) { return true }
        
        // 3. 转换为拼音首字母简拼
        let initials = text.components(separatedBy: .punctuationCharacters).joined()
            .compactMap { char -> String? in
                let s = String(char)
                let ms = NSMutableString(string: s) as CFMutableString
                CFStringTransform(ms, nil, kCFStringTransformToLatin, false)
                CFStringTransform(ms, nil, kCFStringTransformStripDiacritics, false)
                return (ms as String).first?.lowercased()
            }.joined()
        
        if initials.contains(cleanQuery) { return true }
        
        return false
    }
}
