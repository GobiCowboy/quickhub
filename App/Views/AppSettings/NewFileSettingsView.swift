import SwiftUI

// MARK: - 新建文件设置

struct NewFileSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customName = ""
    @State private var customExt = ""
    @State private var customIcon = "doc"
    @State private var showIconPicker = false

    private let templateCategories: [(name: String, icon: String, items: [FileTemplatePreset])] = [
        ("new_file.category.office", "doc.text", [
            FileTemplatePreset(name: "空白文本", ext: "txt", icon: "doc.text"),
            FileTemplatePreset(name: "Word", ext: "docx", icon: "doc.fill"),
            FileTemplatePreset(name: "Excel", ext: "xlsx", icon: "tablecells"),
            FileTemplatePreset(name: "PPT", ext: "pptx", icon: "chart.bar"),
            FileTemplatePreset(name: "Pages", ext: "pages", icon: "doc.richtext.fill"),
            FileTemplatePreset(name: "Numbers", ext: "numbers", icon: "tablecells.fill"),
            FileTemplatePreset(name: "Keynote", ext: "key", icon: "play.rectangle.fill"),
            FileTemplatePreset(name: "Markdown", ext: "md", icon: "doc.richtext")
        ]),
        ("new_file.category.coding", "chevron.left.forwardslash.chevron.right", [
            FileTemplatePreset(name: "Swift", ext: "swift", icon: "swift"),
            FileTemplatePreset(name: "Python", ext: "py", icon: "p.square"),
            FileTemplatePreset(name: "JavaScript", ext: "js", icon: "curlybraces"),
            FileTemplatePreset(name: "TypeScript", ext: "ts", icon: "curlybraces"),
            FileTemplatePreset(name: "HTML", ext: "html", icon: "globe"),
            FileTemplatePreset(name: "CSS", ext: "css", icon: "paintbrush"),
            FileTemplatePreset(name: "JSON", ext: "json", icon: "curlybraces.square"),
            FileTemplatePreset(name: "YAML", ext: "yaml", icon: "text.alignleft"),
            FileTemplatePreset(name: "Go", ext: "go", icon: "p.square.fill"),
            FileTemplatePreset(name: "Rust", ext: "rs", icon: "gearshape"),
            FileTemplatePreset(name: "Shell", ext: "sh", icon: "terminal")
        ]),
        ("new_file.category.design", "paintpalette", [
            FileTemplatePreset(name: "PSD", ext: "psd", icon: "photo"),
            FileTemplatePreset(name: "AI", ext: "ai", icon: "pencil.and.outline"),
            FileTemplatePreset(name: "Sketch", ext: "sketch", icon: "pencil.tip"),
            FileTemplatePreset(name: "Figma", ext: "fig", icon: "square.and.pencil")
        ])
    ]

    private var enabledFolderItems: [CommandItem] {
        let group = config.groups.first { $0.name == "新建文件/文件夹" }
        return group?.items.filter { $0.type == .createFolder } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPageHeader(
                    title: localized("new_file.title"),
                    subtitle: localized("new_file.desc"),
                    icon: "doc.badge.plus"
                )

                let enabledTemplates = getEnabledTemplates()

                SettingsSurface(title: localized("common.enabled"), systemImage: "checkmark.circle.fill") {
                    if enabledTemplates.isEmpty && enabledFolderItems.isEmpty {
                        Text(localized("settings.empty.enabled"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(enabledFolderItems) { item in
                                EnabledChip(
                                    icon: item.icon.isEmpty ? "folder.fill" : item.icon,
                                    name: DefaultItemNameMapping.localizedItemName(item.name),
                                    item: item,
                                    onEdit: { onEdit(.folderItem(item)) },
                                    onDelete: { deleteFolderItem(item) }
                                )
                            }
                            ForEach(enabledTemplates) { item in
                                EnabledChip(
                                    icon: item.icon.isEmpty ? "doc" : item.icon,
                                    name: DefaultItemNameMapping.localizedItemName(item.name),
                                    item: item,
                                    onEdit: { onEdit(.template(item)) },
                                    onDelete: { deleteTemplate(item) }
                                )
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("new_file.add"), systemImage: "plus.circle") {
                    VStack(alignment: .leading, spacing: 16) {
                        if enabledFolderItems.isEmpty {
                            SettingsChipSection(
                                title: localized("new_file.category.folder"),
                                icon: "folder.fill"
                            ) {
                                FlowLayout(spacing: 8) {
                                    AddableChip(
                                        icon: "folder.fill",
                                        name: localized("new_file.new_folder"),
                                        item: CommandItem(name: "新建文件夹", icon: "folder.fill", type: .createFolder),
                                        onAdd: { addNewFolder() }
                                    )
                                }
                            }
                        }

                        ForEach(templateCategories, id: \.name) { category in
                            let availablePresets = getAvailablePresets(for: category)
                            if !availablePresets.isEmpty {
                                SettingsChipSection(
                                    title: localized(category.name),
                                    icon: category.icon
                                ) {
                                    FlowLayout(spacing: 8) {
                                        ForEach(availablePresets) { preset in
                                            AddableChip(
                                                icon: preset.icon,
                                                name: preset.name,
                                                item: preset.toCommandItem(),
                                                onAdd: { addTemplate(preset) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("new_file.custom"), systemImage: "plus.square.dashed") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 图标选择
                        Button(action: { showIconPicker = true }) {
                            HStack(spacing: 8) {
                                if let image = IconImageLoader.loadImage(named: customIcon) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .clipShape(RoundedRectangle(cornerRadius: customIcon.hasPrefix("/") ? 4 : 0))
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
                            TextField(localized("editor.field.name_placeholder"), text: $customName)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customName = content
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField(localized("new_file.custom_ext_placeholder"), text: $customExt)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customExt = content
                                }
                            }
                            Button(localized("new_file.add")) {
                                addCustomFile()
                            }
                            .disabled(customExt.isEmpty)
                        }

                        Text(localized("new_file.tip.auto_dot"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .sheet(isPresented: $showIconPicker) {
                    IconPickerSheet(selectedIcon: $customIcon)
                }
            }
            .padding(22)
        }
    }

    private func getEnabledTemplates() -> [CommandItem] {
        let group = config.groups.first { $0.name == "新建文件/文件夹" }
        return group?.items.filter { $0.type == .createFile } ?? []
    }

    private func getAvailablePresets(for category: (name: String, icon: String, items: [FileTemplatePreset])) -> [FileTemplatePreset] {
        let enabledNames = Set(getEnabledTemplates().map { $0.name })
        return category.items.filter { !enabledNames.contains($0.name) }
    }

    private func addTemplate(_ preset: FileTemplatePreset) {
        ensureGroup(name: "新建文件/文件夹", icon: "folder.badge.plus")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "新建文件/文件夹" }) {
            let template = preset.toCommandItem()
            config.groups[groupIndex].items.append(template)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func deleteTemplate(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "新建文件/文件夹" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addNewFolder() {
        ensureGroup(name: "新建文件/文件夹", icon: "folder.badge.plus")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "新建文件/文件夹" }) {
            let folderItem = CommandItem(name: "新建文件夹", icon: "folder.fill", type: .createFolder)
            config.groups[groupIndex].items.append(folderItem)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func deleteFolderItem(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "新建文件/文件夹" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomFile() {
        let ext = customExt.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(".")
            ? String(customExt.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst())
            : customExt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? (ext.isEmpty ? "自定义文件" : ".\(ext)") : trimmedName

        ensureGroup(name: "新建文件/文件夹", icon: "folder.badge.plus")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "新建文件/文件夹" }) {
            let item = CommandItem(name: name, icon: customIcon, type: .createFile, fileExtension: ext)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customName = ""
            customExt = ""
            customIcon = "doc"
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
