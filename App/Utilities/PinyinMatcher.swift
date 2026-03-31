import Foundation

struct PinyinMatcher {
    /// 检查输入的 query 是否能匹配目标文字（支持原文字、全拼或首字母简拼）
    static func match(_ text: String, query: String) -> Bool {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        if cleanQuery.isEmpty { return true }
        
        let lowerText = text.lowercased()
        
        // 1. 直接包含（中文字符或已有的英文字符）
        if lowerText.contains(cleanQuery) {
            return true 
        }
        
        // 2. 转换为拼音全拼
        let pinyin = convertToPinyin(text, stripSpaces: true)
        
        // 3. 转换为拼音首字母简拼
        let initials = extractInitials(text)
        
        print("[PinyinMatch] Query: '\(cleanQuery)', Text: '\(text)', Pinyin: '\(pinyin)', Initials: '\(initials)'")
        
        if pinyin.contains(cleanQuery) || initials.contains(cleanQuery) {
            print("[PinyinMatch] MATCH SUCCESS!")
            return true
        }
        
        return false
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
            // 转拼音
            CFStringTransform(ms, nil, kCFStringTransformToLatin, false)
            // 去掉音标
            CFStringTransform(ms, nil, kCFStringTransformStripDiacritics, false)
            // 此时 ms 可能是 "zhōng" -> "zhong"
            if let firstChar = (ms as String).first {
                initials.append(firstChar.lowercased())
            }
        }
        return initials
    }
}
