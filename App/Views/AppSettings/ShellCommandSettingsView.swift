import SwiftUI

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""
    @State private var customIcon = "command"
    @State private var showIconPicker = false

    private let presetCategories: [(name: String, icon: String, items: [ShellPreset])] = [
        (
            name: "shell.category.basic",
            icon: "terminal",
            items: [
                ShellPreset(name: "shell.file_info", command: InternalShellCommand.fileInfo, icon: "info.circle", openTerminal: false),
                ShellPreset(name: "shell.copy_path", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false),
                ShellPreset(name: "shell.open_in_terminal", command: "open -b com.apple.Terminal '{dir}'", icon: "terminal", openTerminal: false),
                ShellPreset(name: "shell.open_in_iterm", command: "open -b com.googlecode.iterm2 '{dir}'", icon: "terminal", openTerminal: false),
                ShellPreset(name: "shell.open_in_vscode", command: "open -b com.microsoft.VSCode '{dir}'", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false),
                ShellPreset(name: "shell.open_in_atom", command: "open -b com.github.atom '{dir}'", icon: "circle.grid.3x3.fill", openTerminal: false),
            ]
        ),
        (
            name: "shell.category.macos",
            icon: "desktopcomputer",
            items: [
                ShellPreset(name: "shell.create_shortcut_desktop", command: "ln -s '{path}' ~/Desktop/", icon: "arrow.uturn.forward", openTerminal: false),
                ShellPreset(name: "shell.compress_zip", command: "ditto -c -k --sequesterRsrc '{path}' \"$(dirname '{path}')/{filename}.zip\"", icon: "archivebox", openTerminal: false),
                ShellPreset(name: "shell.view_icon", command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to icon view'", icon: "square.grid.2x2", openTerminal: false),
                ShellPreset(name: "shell.view_list", command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to list view'", icon: "list.bullet", openTerminal: false),
                ShellPreset(name: "shell.view_column", command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to column view'", icon: "sidebar.left", openTerminal: false),
                ShellPreset(name: "shell.view_gallery", command: "osascript -e 'tell application \"Finder\" to activate' -e 'delay 0.1' -e 'tell application \"Finder\" to set current view of front Finder window to flow view'", icon: "rectangle.split.3x1", openTerminal: false),
            ]
        ),
        (
            name: "shell.category.developer",
            icon: "hammer",
            items: [
                ShellPreset(name: "shell.open_in_vscode", command: "open -b com.microsoft.VSCode '{dir}'", icon: "chevron.left.forwardslash.chevron.right", openTerminal: false),
                ShellPreset(name: "shell.git_status", command: "cd '{dir}' && git status", icon: "arrow.triangle.branch", openTerminal: true),
                ShellPreset(name: "shell.git_add", command: "cd '{dir}' && git add '{filename}'", icon: "plus.circle", openTerminal: true),
                ShellPreset(name: "shell.git_diff", command: "cd '{dir}' && git diff '{filename}'", icon: "doc.text.magnifyingglass", openTerminal: true),
                ShellPreset(name: "shell.git_log", command: "cd '{dir}' && git log --oneline -20", icon: "clock.arrow.circlepath", openTerminal: true),
            ]
        ),
    ]

    private let commandPresets: [CommandPreset] = [
        CommandPreset(name: "command.cut_file", icon: "scissors", type: .cutFile),
        CommandPreset(name: "command.copy_file", icon: "doc.on.doc", type: .copyFile),
        CommandPreset(name: "command.paste_file", icon: "doc.on.clipboard", type: .pasteFile),
        CommandPreset(name: "command.move_to_trash", icon: "trash", type: .moveToTrash),
        CommandPreset(name: "command.rename", icon: "pencil", type: .rename),
        CommandPreset(name: "command.open_with", icon: "app.badge.checkmark", type: .openWith),
        CommandPreset(name: "command.share_file", icon: "square.and.arrow.up", type: .shareFile),
    ]

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
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(enabledCommands) { item in
                                EnabledChip(
                                    icon: item.icon,
                                    name: DefaultItemNameMapping.localizedItemName(item.name),
                                    item: item,
                                    onEdit: { onEdit(item.type == .shell ? .shell(item) : .genericCommand(item)) },
                                    onDelete: { deleteCommand(item) }
                                )
                            }
                        }
                    }
                }

                ForEach(presetCategories, id: \.name) { category in
                    let availablePresets = getAvailablePresets(for: category.items)
                    if !availablePresets.isEmpty {
                        SettingsChipSection(
                            title: localized(category.name),
                            icon: category.icon
                        ) {
                            FlowLayout(spacing: 8) {
                                ForEach(availablePresets) { cmd in
                                    AddableChip(
                                        icon: cmd.icon,
                                        name: localized(cmd.name),
                                        item: cmd.toCommandItem(),
                                        onAdd: { addCommand(cmd) }
                                    )
                                }
                            }
                        }
                    }
                }

                // Windows 风格预设
                let availableCommandPresets = getAvailableCommandPresets()
                if !availableCommandPresets.isEmpty {
                    SettingsChipSection(
                        title: localized("shell.category.windows"),
                        icon: "rectangle.on.rectangle"
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(availableCommandPresets) { cmd in
                                AddableChip(
                                    icon: cmd.icon,
                                    name: localized(cmd.name),
                                    item: cmd.toCommandItem(),
                                    onAdd: { addCommandPreset(cmd) }
                                )
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("shell.add_custom"), systemImage: "square.and.pencil") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 图标选择
                        Button(action: { showIconPicker = true }) {
                            HStack(spacing: 8) {
                                if customIcon.hasPrefix("/"), let image = NSImage(contentsOfFile: customIcon) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Image(systemName: customIcon)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.accentColor)
                                }

                                Text(localized("icon_picker.set_icon"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)

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
                .sheet(isPresented: $showIconPicker) {
                    IconPickerSheet(selectedIcon: $customIcon)
                }
            }
            .padding(22)
        }
    }

    private func getEnabledCommands() -> [CommandItem] {
        let group = config.groups.first { $0.name == "命令" }
        let result = group?.items ?? []
        print("[ShellCommandSettings] getEnabledCommands: count=\(result.count), items=\(result.map { $0.name }))")
        return result
    }

    private func getAvailablePresets(for presets: [ShellPreset]) -> [ShellPreset] {
        let enabledNames = Set(getEnabledCommands().map { $0.name })
        return presets.filter { !$0.command.isEmpty && !enabledNames.contains($0.name) && $0.isAvailable }
    }

    private func getAvailableCommandPresets() -> [CommandPreset] {
        let enabledNames = Set(getEnabledCommands().map { $0.name })
        return commandPresets.filter { !enabledNames.contains($0.name) }
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

    private func addCommandPreset(_ cmd: CommandPreset) {
        ensureGroup(name: "命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) {
            let item = cmd.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomCommand() {
        print("[ShellCommandSettings] addCustomCommand called: \(customCommandName)")
        ensureGroup(name: "命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "命令" }) {
            let item = CommandItem(
                name: customCommandName,
                icon: customIcon,
                type: .shell,
                command: customCommand,
                openInTerminal: true
            )
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customCommand = ""
            customCommandName = ""
            customIcon = "command"
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
