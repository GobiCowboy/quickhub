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

        // 如果没有默认配置，保留空状态，由用户自己添加需要的启动项
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

        if config.settings.legacyDefaultsPrunedRevision < 2 {
            if pruneLegacyStarterItems() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 2
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
        return []
    }

    private func pruneLegacyStarterItems() -> Bool {
        var changed = false

        func pruneItems(in groupName: String, shouldRemove: (CommandItem) -> Bool) {
            guard let groupIndex = config.groups.firstIndex(where: { $0.name == groupName }) else { return }
            let originalCount = config.groups[groupIndex].items.count
            config.groups[groupIndex].items.removeAll(where: shouldRemove)
            if config.groups[groupIndex].items.count != originalCount {
                changed = true
            }
        }

        pruneItems(in: "新建文件/文件夹") { item in
            item.type == .createFolder && item.name == "新建文件夹"
        }

        pruneItems(in: "打开文件夹") { item in
            item.type == .openFinder && (item.name == "桌面" || item.name == "下载")
        }

        pruneItems(in: "打开应用") { item in
            let terminalPaths = [
                "/Applications/Utilities/Terminal.app",
                "/System/Applications/Utilities/Terminal.app"
            ]

            if item.type == .openApp {
                return item.name == "终端"
                    || item.name == "Terminal"
                    || item.targetPath.map { terminalPaths.contains($0) } == true
            }

            if item.type == .shell {
                return item.name == "终端"
                    || item.name == "Terminal"
                    || item.command?.contains("Terminal") == true
                    || item.command?.contains("open -a Terminal") == true
                    || item.command?.contains("com.apple.Terminal") == true
            }

            return false
        }

        pruneItems(in: "命令") { item in
            (item.type == .shell && item.name == "文件信息" && item.command == InternalShellCommand.fileInfo)
                || (item.type == .copyPath && item.name == "复制路径")
                || (item.type == .shell && item.name == "在 VS Code 打开")
                || (item.type == .shell && item.name == "在 Atom 打开")
        }

        return changed
    }
}
