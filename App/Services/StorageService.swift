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

        if config.groups.isEmpty {
            config.groups = Self.defaultGroups()
        }

        migrateSettingsIfNeeded()

        if ensureRequiredGroups() {
            saveToDisk()
        }
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

        if config.settings.legacyDefaultsPrunedRevision < 3 {
            if migrateAddDefaultGroups() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 3
            changed = true
        }

        if config.settings.legacyDefaultsPrunedRevision < 4 {
            if migrateUpdateCommandStrings() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 4
            changed = true
        }

        if config.settings.legacyDefaultsPrunedRevision < 5 {
            if migrateRemoveRetractedCommands() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 5
            changed = true
        }

        if config.settings.legacyDefaultsPrunedRevision < 6 {
            if migrateUpdateIcons() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 6
            changed = true
        }

        if config.settings.legacyDefaultsPrunedRevision < 7 {
            if migrateRemoveLegacyStarterCommands() {
                changed = true
            }
            config.settings.legacyDefaultsPrunedRevision = 7
            changed = true
        }

        // 每次启动清理旧版命令名称（不限 revision）
        if migrateCleanStaleCommands() {
            changed = true
        }

        // 清理错误添加的顶级分组（v3 迁移曾误创建）
        let staleGroups = ["macOS 常用", "开发者"]
        let beforeCount = config.groups.count
        config.groups.removeAll { staleGroups.contains($0.name) }
        if config.groups.count != beforeCount {
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
        [
            CommandGroup(name: "新建文件/文件夹", icon: "folder.badge.plus", items: [
                CommandItem(name: "新建文件夹", icon: "folder.fill", type: .createFolder),
                CommandItem(name: "Markdown", icon: "doc.richtext", type: .createFile, fileExtension: "md"),
                CommandItem(name: "Pages", icon: "doc.richtext.fill", type: .createFile, fileExtension: "pages"),
            ]),
            CommandGroup(name: "命令", icon: "terminal"),
            CommandGroup(name: "打开文件夹", icon: "folder", items: [
                CommandItem(name: "open_folder.downloads", icon: "arrow.down.circle.fill", type: .openFinder, targetPath: "~/Downloads"),
                CommandItem(name: "open_folder.applications", icon: "app.fill", type: .openFinder, targetPath: "~/Applications"),
                CommandItem(name: "open_folder.documents", icon: "doc.fill", type: .openFinder, targetPath: "~/Documents"),
            ]),
            CommandGroup(name: "打开应用", icon: "app", items: [
                CommandItem(name: "Pages", icon: "doc.richtext.fill", type: .openApp, targetPath: "/Applications/Pages.app"),
                CommandItem(name: "Keynote", icon: "play.rectangle.fill", type: .openApp, targetPath: "/Applications/Keynote.app"),
            ]),
        ]
    }

    static func requiredGroups() -> [CommandGroup] {
        [
            CommandGroup(name: "新建文件/文件夹", icon: "folder.badge.plus"),
            CommandGroup(name: "打开文件夹", icon: "folder"),
            CommandGroup(name: "打开应用", icon: "app"),
            CommandGroup(name: "命令", icon: "terminal")
        ]
    }

    /// 命令分组默认项
    private static func defaultCommandItems() -> [CommandItem] {
        var items: [CommandItem] = []

        // —— 基础命令 ——
        items.append(contentsOf: [
            CommandItem(name: "shell.file_info", icon: "openmoji/file_info.png", type: .shell,
                        command: InternalShellCommand.fileInfo, openInTerminal: false),
            CommandItem(name: "shell.copy_path", icon: "openmoji/copy_path.png", type: .shell,
                        command: "echo -n '{path}' | pbcopy", openInTerminal: false),
            CommandItem(name: "shell.open_in_terminal", icon: "openmoji/terminal.png", type: .shell,
                        command: "open -b com.apple.Terminal '{dir}'", openInTerminal: false),
        ])

        // —— macOS ——
        items.append(contentsOf: [
            CommandItem(name: "shell.create_shortcut_desktop", icon: "openmoji/shortcut.png", type: .shell,
                        command: "ln -s '{path}' ~/Desktop/", openInTerminal: false),
            CommandItem(name: "shell.compress_zip", icon: "openmoji/compress.png", type: .shell,
                        command: "ditto -c -k --sequesterRsrc '{path}' \"$(dirname '{path}')/{filename}.zip\"", openInTerminal: false),
            CommandItem(name: "shell.view_icon", icon: "openmoji/view_grid.png", type: .shell,
                        command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to icon view'", openInTerminal: false),
            CommandItem(name: "shell.view_list", icon: "openmoji/view_list.png", type: .shell,
                        command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to list view'", openInTerminal: false),
            CommandItem(name: "shell.view_column", icon: "openmoji/view_column.png", type: .shell,
                        command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to column view'", openInTerminal: false),
            CommandItem(name: "shell.view_gallery", icon: "openmoji/view_gallery.png", type: .shell,
                        command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to flow view'", openInTerminal: false),
        ])

        // —— 开发者 ——
        // VS Code：仅在已安装时添加
        if AppAvailability.isInstalled(
            bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"],
            appPaths: ["/Applications/Visual Studio Code.app"]
        ) {
            items.append(CommandItem(name: "shell.open_in_vscode", icon: "openmoji/terminal.png", type: .shell,
                                     command: "open -b com.microsoft.VSCode '{path}'", openInTerminal: false))
        }

        items.append(contentsOf: [
            CommandItem(name: "shell.git_status", icon: "openmoji/git_status.png", type: .shell,
                        command: "cd '{dir}' && git status", openInTerminal: true),
            CommandItem(name: "shell.git_add", icon: "openmoji/git_add.png", type: .shell,
                        command: "cd '{dir}' && git add '{filename}'", openInTerminal: true),
            CommandItem(name: "shell.git_diff", icon: "openmoji/git_diff.png", type: .shell,
                        command: "cd '{dir}' && git diff '{filename}'", openInTerminal: true),
            CommandItem(name: "shell.git_log", icon: "openmoji/git_log.png", type: .shell,
                        command: "cd '{dir}' && git log --oneline -20", openInTerminal: true),
        ])

        return items
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

    private func ensureRequiredGroups() -> Bool {
        var changed = false

        for requiredGroup in Self.requiredGroups() {
            if !config.groups.contains(where: { $0.name == requiredGroup.name }) {
                config.groups.append(requiredGroup)
                changed = true
            }
        }

        return changed
    }

    /// 为已有用户补入新的默认命令项（不覆盖用户已有配置）
    private func migrateAddDefaultGroups() -> Bool {
        let defaults = Self.defaultCommandItems()
        let defaultNames = Set(defaults.map { $0.name })

        // 找到 "命令" 分组，没有则创建
        let groupIndex: Int
        if let idx = config.groups.firstIndex(where: { $0.name == "命令" }) {
            groupIndex = idx
        } else {
            config.groups.append(CommandGroup(name: "命令", icon: "terminal"))
            groupIndex = config.groups.count - 1
        }

        // 只添加用户还没有的命令
        let existingNames = Set(config.groups[groupIndex].items.map { $0.name })
        let toAdd = defaults.filter { !existingNames.contains($0.name) }
        if toAdd.isEmpty { return false }

        config.groups[groupIndex].items.append(contentsOf: toAdd)
        return true
    }

    /// 更新已有命令的命令字符串（修复 bug 后同步更新用户已有配置）
    private func migrateUpdateCommandStrings() -> Bool {
        let defaults = Self.defaultCommandItems()
        let defaultsByName = Dictionary(uniqueKeysWithValues: defaults.map { ($0.name, $0) })
        var changed = false

        for groupIndex in config.groups.indices {
            for itemIndex in config.groups[groupIndex].items.indices {
                let item = config.groups[groupIndex].items[itemIndex]
                if let defaultItem = defaultsByName[item.name],
                   item.command != defaultItem.command {
                    config.groups[groupIndex].items[itemIndex].command = defaultItem.command
                    changed = true
                }
            }
        }
        return changed
    }

    /// 移除已撤回的默认命令
    private func migrateRemoveRetractedCommands() -> Bool {
        let retractedNames: Set<String> = [
            "shell.show_hidden_files",
            "shell.hide_hidden_files",
            "shell.sort_name",
            "shell.sort_date",
            "shell.sort_size",
            "shell.sort_kind",
            "shell.json_format",
        ]
        var changed = false
        for groupIndex in config.groups.indices {
            let beforeCount = config.groups[groupIndex].items.count
            config.groups[groupIndex].items.removeAll { retractedNames.contains($0.name) }
            if config.groups[groupIndex].items.count != beforeCount {
                changed = true
            }
        }
        return changed
    }

    /// 每次启动清理旧版/错误添加的命令，重命名为新版
    /// 更新默认命令的图标为 OpenMoji
    private func migrateUpdateIcons() -> Bool {
        let defaults = Self.defaultCommandItems()
        let defaultsByName = Dictionary(uniqueKeysWithValues: defaults.map { ($0.name, $0.icon) })
        var changed = false

        for groupIndex in config.groups.indices {
            for itemIndex in config.groups[groupIndex].items.indices {
                let item = config.groups[groupIndex].items[itemIndex]
                if let newIcon = defaultsByName[item.name], item.icon != newIcon {
                    config.groups[groupIndex].items[itemIndex].icon = newIcon
                    changed = true
                }
            }
        }
        return changed
    }

    private func migrateCleanStaleCommands() -> Bool {
        var changed = false
        for groupIndex in config.groups.indices {
            // 移除已撤回的 Windows 默认命令（cut/copy/paste/trash/rename/open_with/share）
            let beforeCount = config.groups[groupIndex].items.count
            config.groups[groupIndex].items.removeAll { item in
                ["command.cut_file", "command.copy_file", "command.paste_file",
                 "command.move_to_trash", "command.rename",
                 "command.open_with", "command.share_file",
                 "shell.create_alias_desktop",
                 "shell.show_hidden_files", "shell.hide_hidden_files",
                 "shell.sort_name", "shell.sort_date", "shell.sort_size", "shell.sort_kind",
                 "shell.json_format"].contains(item.name)
            }
            if config.groups[groupIndex].items.count != beforeCount {
                changed = true
            }
        }
        return changed
    }

    /// v7: 新产品策略改为默认全空，移除历史自动塞入的命令 starter pack
    private func migrateRemoveLegacyStarterCommands() -> Bool {
        let legacyStarterNames: Set<String> = [
            "shell.file_info",
            "shell.copy_path",
            "shell.open_in_terminal",
            "shell.create_shortcut_desktop",
            "shell.compress_zip",
            "shell.view_icon",
            "shell.view_list",
            "shell.view_column",
            "shell.view_gallery",
            "shell.git_status",
            "shell.git_add",
            "shell.git_diff",
            "shell.git_log"
        ]

        guard let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) else {
            return false
        }

        let beforeCount = config.groups[groupIndex].items.count
        config.groups[groupIndex].items.removeAll { legacyStarterNames.contains($0.name) }
        return config.groups[groupIndex].items.count != beforeCount
    }
}
