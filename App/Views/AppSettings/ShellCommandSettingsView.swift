import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private let presetCommands: [ShellPreset] = [
        ShellPreset(name: "shell.copy_path", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false),
        ShellPreset(name: "shell.open_in_terminal", command: "open -a Terminal '{dir}'", icon: "terminal", openTerminal: false),
        ShellPreset(name: "shell.open_in_iterm", command: "open -a iTerm '{dir}'", icon: "terminal", openTerminal: false),
        ShellPreset(name: "shell.open_in_vscode", command: "cd '{dir}' && code .", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("shell.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(localized("shell.desc"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                // 已启用
                let enabledCommands = getEnabledCommands()

                if !enabledCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(localized("common.enabled"), systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)

                        FlowLayout(spacing: 8) {
                            ForEach(enabledCommands) { item in
                                EnabledChip(
                                    icon: item.icon.isEmpty ? "command" : item.icon,
                                name: localized(item.name),
                                    onEdit: { onEdit(.shell(item)) },
                                    onDelete: { deleteCommand(item) }
                                )
                            }
                        }
                    }

                    Divider()
                }

                // 可添加
                Text(localized("shell.preset_commands"))
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    FlowLayout(spacing: 8) {
                        ForEach(getAvailableCommands()) { cmd in
                            AddableChip(
                                icon: cmd.icon,
                                name: localized(cmd.name),
                                onAdd: { addCommand(cmd) }
                            )
                        }
                    }
                }
                .frame(height: 40)

                Divider()

                // 自定义命令
                Text(localized("shell.add_custom"))
                    .font(.headline)

                VStack(spacing: 12) {
                    TextField(localized("shell.command_name_placeholder"), text: $customCommandName)
                        .textFieldStyle(.roundedBorder)

                    TextField(localized("shell.command_content_placeholder"), text: $customCommand)
                        .textFieldStyle(.roundedBorder)

                    Text(localized("shell.tip.placeholders"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localized("shell.examples"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(localized("shell.example.copy_path"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(localized("shell.example.terminal"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(localized("shell.example.iterm"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(localized("shell.example.vscode"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(localized("shell.add_command")) {
                        addCustomCommand()
                    }
                    .disabled(customCommand.isEmpty || customCommandName.isEmpty)
                }
            }
            .padding(20)
        }
    }

    private func getEnabledCommands() -> [CommandItem] {
        let group = config.groups.first { $0.name == "命令" }
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
        ensureGroup(name: "命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) {
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
        ensureGroup(name: "命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) {
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
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) {
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
