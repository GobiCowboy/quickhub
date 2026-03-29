import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private let presetCommands: [ShellPreset] = [
        ShellPreset(name: "复制路径", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false),
        ShellPreset(name: "在终端打开", command: "cd '{dir}' && open -a Terminal", icon: "terminal", openTerminal: false),
        ShellPreset(name: "在终端新标签页打开", command: "cd '{dir}' && osascript -e 'tell app \"Terminal\" to do script \"cd {dir}\"'", icon: "terminal.fill", openTerminal: false),
        ShellPreset(name: "在 iTerm2 打开", command: "cd '{dir}' && open -a iTerm", icon: "terminal", openTerminal: false),
        ShellPreset(name: "在 iTerm2 新标签页打开", command: "cd '{dir}' && osascript -e 'tell app \"iTerm\" to create session with default profile'", icon: "terminal.fill", openTerminal: false),
        ShellPreset(name: "在 tmux 打开", command: "cd '{dir}' && tmux new-session -d -s temp && tmux send-keys 'cd {dir}' Enter", icon: "rectangle.split.3x1", openTerminal: false),
        ShellPreset(name: "在 VS Code 打开", command: "cd '{dir}' && code .", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false)
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

                Text("提示: 使用 {path} 表示选中文件路径，{dir} 表示目录，{filename} 表示文件名")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("示例:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("复制路径: echo -n '{path}' | pbcopy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("终端打开: cd '{dir}' && open -a Terminal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("iTerm2: cd '{dir}' && open -a iTerm")
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
