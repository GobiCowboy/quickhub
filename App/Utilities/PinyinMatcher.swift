import Foundation

struct PinyinMatcher {
    /// 检查输入的 query 是否能匹配目标文字（支持原文字、全拼或首字母简拼）
    static func match(_ text: String, query: String) -> Bool {
        return score(text, query: query) > 0
    }

    /// 返回匹配相关度，分数越高越靠前；0 表示不匹配。
    static func score(_ text: String, query: String) -> Int {
        let cleanQuery = normalize(query)
        guard !cleanQuery.isEmpty else { return 1 }

        let cleanText = normalize(text)
        let pinyinFull = convertToPinyin(text, stripSpaces: true)
        let initials = extractInitials(text)
        let isCJKText = containsCJK(text)

        var bestScore = 0

        // 1. 完全一致
        if cleanText == cleanQuery {
            bestScore = max(bestScore, isCJKText ? 1000 : 900)
        }

        // 2. 直接前缀 / 包含
        if cleanText.hasPrefix(cleanQuery) {
            bestScore = max(bestScore, isCJKText ? 860 : 640)
        } else if cleanText.contains(cleanQuery) {
            bestScore = max(bestScore, isCJKText ? 760 : 520)
        }

        // 3. 全拼
        if pinyinFull.hasPrefix(cleanQuery) {
            bestScore = max(bestScore, isCJKText ? 980 : 700)
        } else if pinyinFull.contains(cleanQuery) {
            bestScore = max(bestScore, isCJKText ? 720 : 480)
        }

        // 4. 首字母
        if initials.hasPrefix(cleanQuery) {
            bestScore = max(bestScore, isCJKText ? 990 : 620)
        } else if isSubsequence(cleanQuery, in: initials) {
            bestScore = max(bestScore, isCJKText ? 780 : 500)
        }

        return bestScore
    }

    static func score(item: CommandItem, query: String) -> Int {
        searchCandidates(for: item).reduce(0) { partialResult, candidate in
            max(partialResult, score(candidate, query: query))
        }
    }

    private static func searchCandidates(for item: CommandItem) -> [String] {
        var candidates: [String] = [
            item.name,
            DefaultItemNameMapping.localizedItemName(item.name)
        ]

        if let command = item.command, !command.isEmpty {
            candidates.append(command)
        }

        if let targetPath = item.targetPath, !targetPath.isEmpty {
            candidates.append(URL(fileURLWithPath: targetPath).lastPathComponent)
        }

        switch item.type {
        case .copyPath:
            candidates.append(contentsOf: [
                "复制路径",
                "复制",
                "路径",
                "copy path",
                "copy",
                "path"
            ])
        case .shell:
            if item.command == InternalShellCommand.fileInfo || item.name == "文件信息" || item.name == "shell.file_info" {
                candidates.append(contentsOf: [
                    "文件信息",
                    "file info",
                    "get info",
                    "getinfo",
                    "info"
                ])
            }
        case .openApp:
            candidates.append(contentsOf: ["打开应用", "app", "application"])
        case .openFinder:
            candidates.append(contentsOf: ["打开文件夹", "folder", "finder"])
        case .createFile:
            candidates.append(contentsOf: ["新建文件", "new file", "file"])
        case .createFolder:
            candidates.append(contentsOf: ["新建文件夹", "new folder", "folder"])
        case .bitwardenSearch:
            candidates.append(contentsOf: ["密码管理", "password", "vault"])
        }

        return candidates
            .map(normalize)
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) || // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) || // CJK Unified Ideographs Extension A
            (0xF900...0xFAFF).contains(scalar.value)    // CJK Compatibility Ideographs
        }
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
