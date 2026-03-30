import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private let presetCommands: [ShellPreset] = [
        ShellPreset(name: "复制路径", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false),
        ShellPreset(name: "在终端打开", command: "osascript -e 'tell application \"Terminal\" to do script \"cd \\\"{dir}\\\" && zsh\"'", icon: "terminal", openTerminal: false),
        ShellPreset(name: "在 iTerm2 打开", command: "osascript -e 'tell application \"iTerm\" to create session with default profile' -e 'tell session -1 of window 1 to write text \"cd \\\"{dir}\\\"\"'", icon: "terminal", openTerminal: false),
        ShellPreset(name: "在 VS Code 打开", command: "cd '{dir}' && code .", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false)
    ]

    var body: some View {
        ScrollView {
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

                ScrollView(.horizontal, showsIndicators: false) {
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
                .frame(height: 40)

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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("示例:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("复制路径: echo -n '{path}' | pbcopy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("终端打开: osascript -e 'tell application \"Terminal\" to do script \"cd \\\"{dir}\\\"\"'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("iTerm2: osascript -e 'tell application \"iTerm\" to create session with default profile' -e 'tell session -1 of window 1 to write text \"cd \\\"{dir}\\\"\"'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("VSCode: cd '{dir}' && code .")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("添加命令") {
                        addCustomCommand()
                    }
                    .disabled(customCommand.isEmpty || customCommandName.isEmpty)
                }
            }
            .padding(20)
        }
    }

    private func getEnabledCommands() -> [CommandItem] {
        let group = config.groups.first { $0.name == "终端命令" }
        let result = group?.items.filter { $0.type == .shell } ?? []
        print("[ShellCommandSettings] getEnabledCommands: count=\(result.count), items=\(result.map { $0.name }))")
        return result
    }

    private func getAvailableCommands() -> [ShellPreset] {
        let enabledNames = Set(getEnabledCommands().map { $0.name })
        let result = presetCommands.filter { !enabledNames.contains($0.name) }
        print("[ShellCommandSettings] getAvailableCommands: enabledNames=\(enabledNames), available=\(result.map { $0.name }))")
        return result
    }

    private func addCommand(_ cmd: ShellPreset) {
        print("[ShellCommandSettings] addCommand called: \(cmd.name)")
        ensureGroup(name: "终端命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            let item = cmd.toCommandItem()
            print("[ShellCommandSettings] Adding item: \(item.name), id=\(item.id)")
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            print("[ShellCommandSettings] After add - groups: \(config.groups.map { "\($0.name): \($0.items.count) items" })")
        }
    }

    private func addCustomCommand() {
        print("[ShellCommandSettings] addCustomCommand called: \(customCommandName)")
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
        print("[ShellCommandSettings] deleteCommand called: \(item.name), id=\(item.id)")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            print("[ShellCommandSettings] Before delete - items count: \(config.groups[groupIndex].items.count)")
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            print("[ShellCommandSettings] After delete - items count: \(config.groups[groupIndex].items.count)")
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
