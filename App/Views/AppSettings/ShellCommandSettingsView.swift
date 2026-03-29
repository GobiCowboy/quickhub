import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private let presetCommands: [ShellPreset] = [
        ShellPreset(name: "Git 状态", command: "git status", icon: "arrow.triangle.branch", openTerminal: true),
        ShellPreset(name: "Git 拉取", command: "git pull", icon: "arrow.down.circle", openTerminal: true),
        ShellPreset(name: "Git 推送", command: "git push", icon: "arrow.up.circle", openTerminal: true),
        ShellPreset(name: "Git 分支", command: "git branch -a", icon: "arrow.triangle.branch", openTerminal: true),
        ShellPreset(name: "Docker 容器", command: "docker ps", icon: "shippingbox.fill", openTerminal: true),
        ShellPreset(name: "Docker 镜像", command: "docker images", icon: "shippingbox", openTerminal: true),
        ShellPreset(name: "NPM 依赖", command: "npm install", icon: "cube.box", openTerminal: true),
        ShellPreset(name: "PIP 列表", command: "pip list", icon: "cube.box.fill", openTerminal: true),
        ShellPreset(name: "复制路径", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("命令行工具")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择在右键菜单中显示的命令")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            let enabledCommands = getEnabledCommands()

            if !enabledCommands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(enabledCommands) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "command" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.shell(item)) },
                                onDelete: { deleteCommand(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加
            Text("预设命令")
                .font(.headline)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(getAvailableCommands()) { cmd in
                        AddableChip(
                            icon: cmd.icon,
                            name: cmd.name,
                            onAdd: { addCommand(cmd) }
                        )
                    }
                }
            }

            Divider()

            // 自定义命令
            Text("添加自定义命令")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("命令名称", text: $customCommandName)
                    .textFieldStyle(.roundedBorder)

                TextField("命令内容，如: git status", text: $customCommand)
                    .textFieldStyle(.roundedBorder)

                Text("提示: 使用 {path} 表示选中文件路径，{dir} 表示目录")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("添加命令") {
                    addCustomCommand()
                }
                .disabled(customCommand.isEmpty || customCommandName.isEmpty)
            }

            Spacer()
        }
        .padding(20)
    }

    private func getEnabledCommands() -> [CommandItem] {
        let group = config.groups.first { $0.name == "终端命令" }
        return group?.items.filter { $0.type == .shell } ?? []
    }

    private func getAvailableCommands() -> [ShellPreset] {
        let enabledNames = Set(getEnabledCommands().map { $0.name })
        return presetCommands.filter { !enabledNames.contains($0.name) }
    }

    private func addCommand(_ cmd: ShellPreset) {
        ensureGroup(name: "终端命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            let item = cmd.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomCommand() {
        ensureGroup(name: "终端命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            let item = CommandItem(
                name: customCommandName,
                icon: "command",
                type: .shell,
                command: customCommand,
                openInTerminal: true
            )
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customCommand = ""
            customCommandName = ""
        }
    }

    private func deleteCommand(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
