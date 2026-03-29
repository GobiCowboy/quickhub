import SwiftUI

// MARK: - 新建文件设置

struct NewFileSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customExt = ""

    private let templateCategories: [(name: String, icon: String, items: [FileTemplatePreset])] = [
        ("办公", "doc.text", [
            FileTemplatePreset(name: "空白文本", ext: "txt", icon: "doc.text"),
            FileTemplatePreset(name: "Word", ext: "docx", icon: "doc.fill"),
            FileTemplatePreset(name: "Excel", ext: "xlsx", icon: "tablecells"),
            FileTemplatePreset(name: "PPT", ext: "pptx", icon: "chart.bar"),
            FileTemplatePreset(name: "Pages", ext: "pages", icon: "doc.richtext.fill"),
            FileTemplatePreset(name: "Numbers", ext: "numbers", icon: "tablecells.fill"),
            FileTemplatePreset(name: "Keynote", ext: "key", icon: "play.rectangle.fill")
        ]),
        ("编程", "chevron.left.forwardslash.chevron.right", [
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
        ("设计", "paintpalette", [
            FileTemplatePreset(name: "PSD", ext: "psd", icon: "photo"),
            FileTemplatePreset(name: "AI", ext: "ai", icon: "pencil.and.outline"),
            FileTemplatePreset(name: "Sketch", ext: "sketch", icon: "pencil.tip"),
            FileTemplatePreset(name: "Figma", ext: "fig", icon: "square.and.pencil")
        ])
    ]

    private var enabledFolderItems: [CommandItem] {
        let group = config.groups.first { $0.name == "文件操作" }
        return group?.items.filter { $0.type == .createFolder } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建文件模板")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择要在右键菜单中显示的文件模板")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用项目
            let enabledTemplates = getEnabledTemplates()

            if !enabledTemplates.isEmpty || !enabledFolderItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        // 新建文件夹
                        ForEach(enabledFolderItems) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "folder.fill" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.folderItem(item)) },
                                onDelete: { deleteFolderItem(item) }
                            )
                        }
                        // 新建文件
                        ForEach(enabledTemplates) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "doc" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.template(item)) },
                                onDelete: { deleteTemplate(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加项目
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 新建文件夹
                    if enabledFolderItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("文件夹", systemImage: "folder.fill")
                                .font(.headline)
                                .foregroundColor(.accentColor)

                            FlowLayout(spacing: 8) {
                                AddableChip(
                                    icon: "folder.fill",
                                    name: "新建文件夹",
                                    onAdd: { addNewFolder() }
                                )
                            }
                        }
                    }

                    // 预设分类
                    ForEach(templateCategories, id: \.name) { category in
                        let availablePresets = getAvailablePresets(for: category)
                        if !availablePresets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(category.name, systemImage: category.icon)
                                    .font(.headline)
                                    .foregroundColor(.accentColor)

                                FlowLayout(spacing: 8) {
                                    ForEach(availablePresets) { preset in
                                        AddableChip(
                                            icon: preset.icon,
                                            name: preset.name,
                                            onAdd: { addTemplate(preset) }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 自定义文件
                    VStack(alignment: .leading, spacing: 8) {
                        Label("自定义", systemImage: "plus.square.dashed")
                            .font(.headline)
                            .foregroundColor(.accentColor)

                        HStack {
                            TextField("扩展名，如 env, gitignore", text: $customExt)
                                .textFieldStyle(.roundedBorder)

                            Button("添加") {
                                addCustomFile()
                            }
                            .disabled(customExt.isEmpty)
                        }

                        Text("提示: 会自动生成 . 符号，如输入 env 会创建 .env 文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(20)
    }

    private func getEnabledTemplates() -> [CommandItem] {
        let group = config.groups.first { $0.name == "文件操作" }
        return group?.items.filter { $0.type == .createFile } ?? []
    }

    private func getAvailablePresets(for category: (name: String, icon: String, items: [FileTemplatePreset])) -> [FileTemplatePreset] {
        let enabledNames = Set(getEnabledTemplates().map { $0.name })
        return category.items.filter { !enabledNames.contains($0.name) }
    }

    private func addTemplate(_ preset: FileTemplatePreset) {
        ensureGroup(name: "文件操作", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "文件操作" }) {
            let template = preset.toCommandItem()
            config.groups[groupIndex].items.append(template)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func deleteTemplate(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "文件操作" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addNewFolder() {
        ensureGroup(name: "文件操作", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "文件操作" }) {
            let folderItem = CommandItem(name: "新建文件夹", icon: "folder.fill", type: .createFolder)
            config.groups[groupIndex].items.append(folderItem)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func deleteFolderItem(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "文件操作" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomFile() {
        let ext = customExt.hasPrefix(".") ? String(customExt.dropFirst()) : customExt
        let name = ext.isEmpty ? "自定义文件" : ".\(ext)"
        let icon = ext.isEmpty ? "doc" : "doc.fill"

        ensureGroup(name: "文件操作", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "文件操作" }) {
            let item = CommandItem(name: name, icon: icon, type: .createFile, fileExtension: ext)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customExt = ""
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
