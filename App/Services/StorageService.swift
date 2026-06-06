import Foundation
import AppKit

/// 存储服务 - 管理配置持久化
class StorageService: StorageServiceProtocol {
    static let shared = StorageService()

    private let configPath: URL
    private var config: AppConfig

    private init() {
        // 配置路径: ~/.config/rightclickx/config.json
        let home = FileManager.default.homeDirectoryForCurrentUser
        configPath = home
            .appendingPathComponent(".config")
            .appendingPathComponent("rightclickx")
            .appendingPathComponent("config.json")

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: configPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 加载配置
        config = StorageService.loadConfig(from: configPath)

        // 如果没有默认配置，注册示例
        if config.groups.isEmpty {
            config.groups = Self.defaultGroups()
        }

        migrateSettingsIfNeeded()
    }

    // MARK: - 公开方法

    func loadConfig() -> AppConfig {
        return config
    }

    func saveConfig(_ config: AppConfig) {
        self.config = config
        saveToDisk()
    }

    private func migrateSettingsIfNeeded() {
        var changed = false

        if config.settings.hotkey == HotkeyConfiguration.legacyDefaultHotkey {
            config.settings.hotkey = HotkeyConfiguration.defaultHotkey
            changed = true
        }

        if changed {
            saveToDisk()
        }
    }

    func addGroup(_ group: CommandGroup) {
        config.groups.append(group)
        saveToDisk()
    }

    func updateGroup(_ group: CommandGroup) {
        if let index = config.groups.firstIndex(where: { $0.id == group.id }) {
            config.groups[index] = group
            saveToDisk()
        }
    }

    func deleteGroup(_ group: CommandGroup) {
        config.groups.removeAll { $0.id == group.id }
        saveToDisk()
    }

    func addItem(_ item: CommandItem, to group: CommandGroup) {
        if let index = config.groups.firstIndex(where: { $0.id == group.id }) {
            config.groups[index].items.append(item)
            saveToDisk()
        }
    }

    func updateItem(_ item: CommandItem, in group: CommandGroup) {
        if let groupIndex = config.groups.firstIndex(where: { $0.id == group.id }),
           let itemIndex = config.groups[groupIndex].items.firstIndex(where: { $0.id == item.id }) {
            config.groups[groupIndex].items[itemIndex] = item
            saveToDisk()
        }
    }

    func deleteItem(_ item: CommandItem, from group: CommandGroup) {
        if let index = config.groups.firstIndex(where: { $0.id == group.id }) {
            config.groups[index].items.removeAll { $0.id == item.id }
            saveToDisk()
        }
    }

    // MARK: - 持久化

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configPath)
        } catch {
            print(localized("storage.save_failed", with: error.localizedDescription))
        }
    }

    private static func loadConfig(from url: URL) -> AppConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppConfig()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            print(localized("storage.load_failed", with: error.localizedDescription))
            return AppConfig()
        }
    }

    // MARK: - 默认配置

    static func defaultGroups() -> [CommandGroup] {
        return [
            CommandGroup(
                name: "新建文件/文件夹",
                icon: "folder.badge.plus",
                items: [
                    CommandItem(
                        name: "新建文件夹",
                        icon: "folder.badge.plus",
                        type: .createFolder
                    )
                ]
            ),
            CommandGroup(
                name: "打开文件夹",
                icon: "folder",
                items: [
                    CommandItem(
                        name: "桌面",
                        icon: "desktopcomputer",
                        type: .openFinder,
                        targetPath: "~/Desktop"
                    ),
                    CommandItem(
                        name: "下载",
                        icon: "arrow.down.circle.fill",
                        type: .openFinder,
                        targetPath: "~/Downloads"
                    )
                ]
            ),
            CommandGroup(
                name: "打开应用",
                icon: "app",
                items: [
                    CommandItem(
                        name: "终端",
                        icon: "terminal",
                        type: .openApp,
                        targetPath: "/Applications/Utilities/Terminal.app"
                    )
                ]
            ),
            CommandGroup(
                name: "命令",
                icon: "terminal",
                items: {
                    var items: [CommandItem] = [
                        CommandItem(
                            name: "文件信息",
                            icon: "info.circle",
                            type: .shell,
                            command: InternalShellCommand.fileInfo,
                            openInTerminal: false
                        ),
                        CommandItem(
                            name: "复制路径",
                            icon: "doc.on.doc",
                            type: .copyPath,
                            command: nil,
                            openInTerminal: false
                        )
                    ]

                    if AppAvailability.isInstalled(bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"], appPaths: ["/Applications/Visual Studio Code.app"]) {
                        items.append(
                            CommandItem(
                                name: "在 VS Code 打开",
                                icon: "chevron.left.forwardslash.chevron.right",
                                type: .shell,
                                command: "open -b com.microsoft.VSCode '{dir}'",
                                openInTerminal: false
                            )
                        )
                    }

                    if AppAvailability.isInstalled(bundleIdentifiers: ["com.github.atom"], appPaths: ["/Applications/Atom.app"]) {
                        items.append(
                            CommandItem(
                                name: "在 Atom 打开",
                                icon: "circle.grid.3x3.fill",
                                type: .shell,
                                command: "open -b com.github.atom '{dir}'",
                                openInTerminal: false
                            )
                        )
                    }

                    return items
                }()
            )
        ]
    }
}
