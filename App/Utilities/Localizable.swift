import Foundation

// MARK: - 本地化字符串辅助

/// 本地化字符串 - 优先使用 LocaleManager，支持应用内语言切换
/// - Parameters:
///   - key: 本地化 key
///   - comment: 翻译备注
/// - Returns: 本地化后的字符串
func localized(_ key: String, comment: String = "") -> String {
    return LocaleManager.shared.localized(key, comment: comment)
}

/// 带参数的本地化字符串
/// - Parameters:
///   - key: 本地化 key
///   - argument: 格式化参数
///   - comment: 翻译备注
/// - Returns: 本地化后的格式化字符串
func localized(_ key: String, with argument: String, comment: String = "") -> String {
    return LocaleManager.shared.localized(key, with: argument, comment: comment)
}

/// 带多个参数的本地化字符串
/// - Parameters:
///   - key: 本地化 key
///   - arguments: 格式化参数数组
///   - comment: 翻译备注
/// - Returns: 本地化后的格式化字符串
func localized(_ key: String, with arguments: [String], comment: String = "") -> String {
    let template = LocaleManager.shared.localized(key, comment: comment)
    return String(format: template, arguments: arguments)
}
