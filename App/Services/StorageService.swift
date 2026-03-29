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
    }

    // MARK: - 公开方法

    func loadConfig() -> AppConfig {
        return config
    }

    func saveConfig(_ config: AppConfig) {
        self.config = config
        saveToDisk()
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
            print("保存配置失败: \(error)")
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
            print("加载配置失败: \(error)")
            return AppConfig()
        }
    }

    // MARK: - 默认配置

    static func defaultGroups() -> [CommandGroup] {
        return [
            CommandGroup(
                name: "文件操作",
                icon: "folder",
                items: [
                    CommandItem(
                        name: "新建 Markdown",
                        icon: "doc.text",
                        type: .createFile,
                        template: "# {{FILENAME}}\n\n{{DATE}}\n",
                        fileExtension: "md"
                    ),
                    CommandItem(
                        name: "新建 Swift 文件",
                        icon: "swift",
                        type: .createFile,
                        template: "//\n//  {{FILENAME}}.swift\n//\n\nimport Foundation\n",
                        fileExtension: "swift"
                    ),
                    CommandItem(
                        name: "复制路径",
                        icon: "doc.on.doc",
                        type: .shell,
                        command: "echo -n '{path}' | pbcopy",
                        openInTerminal: false
                    )
                ]
            ),
            CommandGroup(
                name: "终端命令",
                icon: "terminal",
                items: [
                    CommandItem(
                        name: "在终端打开",
                        icon: "terminal",
                        type: .shell,
                        command: "cd '{dir}' && open -a Terminal",
                        openInTerminal: false
                    ),
                    CommandItem(
                        name: "Git 状态",
                        icon: "arrow.triangle.branch",
                        type: .shell,
                        command: "cd '{dir}' && git status",
                        openInTerminal: true
                    ),
                    CommandItem(
                        name: "Git 拉取",
                        icon: "arrow.down.circle",
                        type: .shell,
                        command: "cd '{dir}' && git pull",
                        openInTerminal: true
                    )
                ]
            ),
            CommandGroup(
                name: "密码管理",
                icon: "key.fill",
                items: [
                    CommandItem(
                        name: "搜索 Bitwarden 密码",
                        icon: "key.fill",
                        type: .bitwardenSearch
                    )
                ]
            ),
            CommandGroup(
                name: "目录快捷",
                icon: "bookmark",
                items: [
                    CommandItem(
                        name: "打开桌面",
                        icon: "desktopcomputer",
                        type: .openFinder,
                        targetPath: "~/Desktop"
                    ),
                    CommandItem(
                        name: "打开下载",
                        icon: "arrow.down.circle.fill",
                        type: .openFinder,
                        targetPath: "~/Downloads"
                    ),
                    CommandItem(
                        name: "打开项目",
                        icon: "folder.fill",
                        type: .openFinder,
                        targetPath: "~/Projects"
                    )
                ]
            )
        ]
    }
}
