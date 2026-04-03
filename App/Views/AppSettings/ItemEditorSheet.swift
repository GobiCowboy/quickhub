import SwiftUI

// MARK: - ItemEditorSheet

struct ItemEditorSheet: View {
    let item: EditableItem
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var command: String = ""
    @State private var targetPath: String = ""
    @State private var template: String = ""
    @State private var fileExtension: String = ""
    @State private var openInTerminal: Bool = true
    @State private var showIconPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(localized("editor.title"))
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 表单内容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("editor.field.name"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField(localized("editor.field.name_placeholder"), text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 图标
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("editor.field.icon"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField(localized("editor.field.icon_placeholder"), text: $icon)
                                .textFieldStyle(.roundedBorder)
                            Button(localized("editor.field.icon_browse")) {
                                openIconPicker()
                            }
                        }
                        Text(localized("editor.field.icon_example"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 类型特定字段
                    switch item {
                    case .template:
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localized("editor.field.extension"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(localized("editor.field.extension_placeholder"), text: $fileExtension)
                                .textFieldStyle(.roundedBorder)
                        }

                    case .folderItem:
                        EmptyView()

                    case .app, .folder:
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localized("editor.field.path"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(localized("common.placeholder.path"), text: $targetPath)
                                .textFieldStyle(.roundedBorder)
                        }

                    case .shell:
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localized("editor.field.command"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $command)
                                .frame(height: 100)
                                .font(.system(.body, design: .monospaced))
                                .border(Color.secondary.opacity(0.3), width: 1)
                            Text(localized("editor.field.placeholder"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Toggle(localized("editor.execute_in_terminal"), isOn: $openInTerminal)

                    case .bitwardenSearch:
                        Text(localized("editor.bitwarden_no_config"))
                            .foregroundColor(.secondary)

                    case .copyPath:
                        Text(localized("editor.copy_path_no_config"))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            // 按钮栏
            HStack {
                Button(localized("editor.delete")) {
                    deleteItem()
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()

                Button(localized("editor.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(localized("editor.save")) {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(selectedIcon: $icon)
        }
        .onAppear {
            loadItemData()
        }
    }

    private func loadItemData() {
        switch item {
        case .template(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon
            fileExtension = cmdItem.fileExtension ?? ""
            template = cmdItem.template ?? ""

        case .folderItem(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon

        case .app(let cmdItem), .folder(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon
            targetPath = cmdItem.targetPath ?? ""

        case .shell(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon
            command = cmdItem.command ?? ""
            openInTerminal = cmdItem.openInTerminal ?? true

        case .bitwardenSearch(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon

        case .copyPath(let cmdItem):
            name = cmdItem.name
            icon = cmdItem.icon
        }
    }

    private func saveChanges() {
        switch item {
        case .template(let cmdItem):
            updateItem(cmdItem)
        case .folderItem(let cmdItem):
            updateItem(cmdItem)
        case .app(let cmdItem):
            updateItem(cmdItem)
        case .folder(let cmdItem):
            updateItem(cmdItem)
        case .shell(let cmdItem):
            updateItem(cmdItem)
        case .bitwardenSearch(let cmdItem):
            updateItem(cmdItem)
        case .copyPath(let cmdItem):
            updateItem(cmdItem)
        }
        onSave()
    }

    private func deleteItem() {
        switch item {
        case .template(let cmdItem):
            deleteFromConfig(cmdItem)
        case .folderItem(let cmdItem):
            deleteFromConfig(cmdItem)
        case .app(let cmdItem):
            deleteFromConfig(cmdItem)
        case .folder(let cmdItem):
            deleteFromConfig(cmdItem)
        case .shell(let cmdItem):
            deleteFromConfig(cmdItem)
        case .bitwardenSearch(let cmdItem):
            deleteFromConfig(cmdItem)
        case .copyPath(let cmdItem):
            deleteFromConfig(cmdItem)
        }
        onSave()
    }

    private func deleteFromConfig(_ item: CommandItem) {
        var config = StorageService.shared.loadConfig()
        for groupIndex in config.groups.indices {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
        }
        StorageService.shared.saveConfig(config)
    }

    private func openIconPicker() {
        showIconPicker = true
    }

    private func updateItem(_ oldItem: CommandItem) {
        var config = StorageService.shared.loadConfig()

        for groupIndex in config.groups.indices {
            if let itemIndex = config.groups[groupIndex].items.firstIndex(where: { $0.id == oldItem.id }) {
                var updatedItem = oldItem
                updatedItem.name = name
                updatedItem.icon = icon

                switch oldItem.type {
                case .createFile:
                    updatedItem.fileExtension = fileExtension
                    updatedItem.template = template
                case .createFolder:
                    break
                case .openFinder, .openApp:
                    updatedItem.targetPath = targetPath
                case .shell:
                    updatedItem.command = command
                    updatedItem.openInTerminal = openInTerminal
                case .copyPath:
                    break
                case .bitwardenSearch:
                    break
                }

                config.groups[groupIndex].items[itemIndex] = updatedItem
                StorageService.shared.saveConfig(config)
                return
            }
        }
    }
}
