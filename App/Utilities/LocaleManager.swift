import Foundation

// MARK: - 语言管理器

class LocaleManager: ObservableObject {
    static let shared = LocaleManager()

    /// 支持的语言
    enum Language: String, CaseIterable {
        case system = "System"
        case english = "English"
        case chinese = "简体中文"

        var bundleIdentifier: String {
            switch self {
            case .system: return ""
            case .english: return "en"
            case .chinese: return "zh-Hans"
            }
        }
    }

    /// 当前选择的语言
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            objectWillChange.send()
            // 发送语言切换通知
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    /// 当前使用的 Bundle
    var bundle: Bundle {
        if currentLanguage != .system {
            let identifier = currentLanguage.bundleIdentifier
            if let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        // 回退到系统默认
        return Bundle.main
    }

    /// 系统是否使用中文
    static var isSystemChinese: Bool {
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] ?? []
        return languages.first?.hasPrefix("zh") ?? false
    }

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // 没有保存的设置，根据系统语言决定默认
            // 如果系统是中文，默认选中文；否则默认选英文
            self.currentLanguage = LocaleManager.isSystemChinese ? .chinese : .english
        }
    }

    /// 获取本地化字符串
    func localized(_ key: String, comment: String = "") -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// 带参数的本地化字符串
    func localized(_ key: String, with argument: String, comment: String = "") -> String {
        let template = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: template, argument)
    }
}

// MARK: - 语言切换通知
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - 默认项名称映射（用于本地化预设项名称）

struct DefaultItemNameMapping {
    /// 预设项名称 -> 本地化 key
    /// 例如: "新建文件夹" -> "new_file.new_folder", "空白文本" -> "new_file.blank_text"
    static let toKey: [String: String] = [
        // 新建文件夹/文件
        "新建文件夹": "new_file.new_folder",
        "空白文本": "new_file.blank_text",
        "Word": "new_file.word",
        "Excel": "new_file.excel",
        "PPT": "new_file.ppt",
        "Pages": "new_file.pages",
        "Numbers": "new_file.numbers",
        "Keynote": "new_file.keynote",
        "Markdown": "new_file.markdown",
        "Swift": "new_file.swift",
        "Python": "new_file.python",
        "JavaScript": "new_file.javascript",
        "TypeScript": "new_file.typescript",
        "HTML": "new_file.html",
        "CSS": "new_file.css",
        "JSON": "new_file.json",
        "YAML": "new_file.yaml",
        "Go": "new_file.go",
        "Rust": "new_file.rust",
        "Shell": "new_file.shell",
        "PSD": "new_file.psd",
        "AI": "new_file.ai",
        "Sketch": "new_file.sketch",
        "Figma": "new_file.figma",
        // 自定义文件
        "自定义文件": "new_file.custom_file",
        // Shell 命令
        "复制路径": "shell.copy_path",
        "在终端打开": "shell.open_in_terminal",
        "在 iTerm2 打开": "shell.open_in_iterm",
        "在 VS Code 打开": "shell.open_in_vscode",
        "shell.copy_path": "shell.copy_path",
        "shell.open_in_terminal": "shell.open_in_terminal",
        "shell.open_in_iterm": "shell.open_in_iterm",
        "shell.open_in_vscode": "shell.open_in_vscode",
        // 打开应用
        "终端": "app.terminal",
        "iTerm": "app.iterm",
        "Visual Studio Code": "app.vscode",
        // 打开文件夹
        "open_folder.desktop": "open_folder.desktop",
        "open_folder.downloads": "open_folder.downloads",
        "open_folder.documents": "open_folder.documents",
        "open_folder.projects": "open_folder.projects",
        "open_folder.applications": "open_folder.applications",
        "open_folder.pictures": "open_folder.pictures",
        "open_folder.music": "open_folder.music",
        "open_folder.movies": "open_folder.movies"
    ]

    /// 获取本地化的项名称
    static func localizedItemName(_ name: String) -> String {
        if let key = toKey[name] {
            return LocaleManager.shared.localized(key)
        }
        // 如果找不到映射，尝试直接作为 key 本地化
        let localized = LocaleManager.shared.localized(name)
        // 如果本地化后返回了 key 本身（说明 name 不是有效的 key），直接返回原名称
        if localized == name {
            return name
        }
        return localized
    }
}

// MARK: - 默认组名映射（用于本地化用户数据中的默认组名）

struct DefaultGroupNameMapping {
    /// 中文组名 -> 英文 key
    static let toEnglish: [String: String] = [
        "新建文件/文件夹": "group.new_file_folder",
        "打开文件夹": "group.open_folder",
        "打开应用": "group.open_app",
        "命令": "group.commands",
        "密码管理": "group.password_management"
    ]

    /// 中文组名 -> 简体中文
    static let toChinese: [String: String] = [
        "新建文件/文件夹": "新建文件/文件夹",
        "打开文件夹": "打开文件夹",
        "打开应用": "打开应用",
        "命令": "命令",
        "密码管理": "密码管理"
    ]

    /// 获取本地化的组名
    static func localizedGroupName(_ name: String) -> String {
        if let key = toEnglish[name] {
            return LocaleManager.shared.localized(key)
        }
        return name
    }
}
