import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private var presetCommands: [ShellPreset] {
        [
            ShellPreset(name: "shell.file_info", command: InternalShellCommand.fileInfo, icon: "info.circle", openTerminal: false),
            ShellPreset(name: "shell.copy_path", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false),
            ShellPreset(name: "shell.open_in_terminal", command: "open -b com.apple.Terminal '{dir}'", icon: "terminal", openTerminal: false),
            ShellPreset(name: "shell.open_in_iterm", command: "open -b com.googlecode.iterm2 '{dir}'", icon: "terminal", openTerminal: false),
            ShellPreset(name: "shell.open_in_vscode", command: "open -b com.microsoft.VSCode '{dir}'", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false),
            ShellPreset(name: "shell.open_in_atom", command: "open -b com.github.atom '{dir}'", icon: "circle.grid.3x3.fill", openTerminal: false)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPageHeader(
                    title: localized("shell.title"),
                    subtitle: localized("shell.desc"),
                    icon: "terminal"
                )

                let enabledCommands = getEnabledCommands()

                SettingsSurface(title: localized("common.enabled"), systemImage: "checkmark.circle.fill") {
                    if enabledCommands.isEmpty {
                        Text(localized("settings.empty.enabled"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 7) {
                            ForEach(enabledCommands) { item in
                                CommandSettingRow(
                                    item: item,
                                    name: localized(item.name),
                                    onEdit: { onEdit(.shell(item)) },
                                    onDelete: { deleteCommand(item) }
                                )
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("shell.preset_commands"), systemImage: "plus.circle") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        FlowLayout(spacing: 8) {
                            ForEach(getAvailableCommands()) { cmd in
                                AddableChip(
                                    icon: cmd.icon,
                                    name: localized(cmd.name),
                                    item: cmd.toCommandItem(),
                                    onAdd: { addCommand(cmd) }
                                )
                            }
                        }
                    }
                    .frame(minHeight: 40)
                }

                SettingsSurface(title: localized("shell.add_custom"), systemImage: "square.and.pencil") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField(localized("shell.command_name_placeholder"), text: $customCommandName)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customCommandName = content
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField(localized("shell.command_content_placeholder"), text: $customCommand)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customCommand = content
                                }
                            }
                        }

                        Text(localized("shell.tip.placeholders"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Spacer()
                            Button(localized("shell.add_command")) {
                                addCustomCommand()
                            }
                            .disabled(customCommand.isEmpty || customCommandName.isEmpty)
                        }
                    }
                }
            }
            .padding(22)
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
        let result = presetCommands.filter { !$0.command.isEmpty && !enabledNames.contains($0.name) && $0.isAvailable }
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
