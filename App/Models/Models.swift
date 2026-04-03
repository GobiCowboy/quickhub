import Foundation
import AppKit

// MARK: - 快捷键配置
struct HotkeyConfiguration: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    static let defaultHotkey = HotkeyConfiguration(keyCode: 12, modifiers: 655360) // ⌥⇧Q

    static let empty = HotkeyConfiguration(keyCode: 0, modifiers: 0)

    var isEmpty: Bool {
        return keyCode == 0 && modifiers == 0
    }
}

// MARK: - 命令项
struct CommandItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String           // 显示名称
    var icon: String          // SF Symbol 图标
    var type: CommandType      // 命令类型
    var enabled: Bool         // 是否启用

    // Shell 命令相关
    var command: String?      // shell 命令
    var openInTerminal: Bool? // 是否在终端中执行

    // 新建文件相关
    var template: String?     // 文件模板内容
    var fileExtension: String? // 文件扩展名

    // 打开目录相关
    var targetPath: String?    // 目标路径

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "command",
        type: CommandType = .shell,
        enabled: Bool = true,
        command: String? = nil,
        openInTerminal: Bool? = nil,
        template: String? = nil,
        fileExtension: String? = nil,
        targetPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.enabled = enabled
        self.command = command
        self.openInTerminal = openInTerminal
        self.template = template
        self.fileExtension = fileExtension
        self.targetPath = targetPath
    }
}

// MARK: - 命令类型
enum CommandType: String, Codable, CaseIterable {
    case shell = "shell"              // Shell 命令
    case copyPath = "copy_path"        // 复制路径
    case createFile = "create_file"    // 新建文件
    case createFolder = "create_folder" // 新建文件夹
    case openFinder = "open_finder"    // 打开目录
    case openApp = "open_app"          // 打开应用
    case bitwardenSearch = "bitwarden_search" // Bitwarden 密码搜索
}

// MARK: - 命令分组
struct CommandGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String           // 分组名称
    var icon: String          // 分组图标
    var enabled: Bool         // 是否启用
    var items: [CommandItem]  // 包含的命令

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder",
        enabled: Bool = true,
        items: [CommandItem] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.enabled = enabled
        self.items = items
    }
}

// MARK: - 完整配置
struct AppConfig: Codable {
    var groups: [CommandGroup]
    var settings: AppSettings

    init(groups: [CommandGroup] = [], settings: AppSettings = AppSettings()) {
        self.groups = groups
        self.settings = settings
    }
}

// MARK: - 应用设置
struct AppSettings: Codable {
    var hotkey: HotkeyConfiguration?
    var launchAtLogin: Bool = false
    var showNotifications: Bool = true

    init() {}
}

// MARK: - Bitwarden 数据模型

struct BitwardenItem: Codable, Identifiable {
    let id: String
    let name: String
    let login: BitwardenLoginItem?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, login, notes
    }
}

struct BitwardenLoginItem: Codable {
    let username: String?
    let password: String?
    let totp: String?
    let uris: [BitwardenUri]?
}

struct BitwardenUri: Codable {
    let uri: String?
    let match: Int?
}
