import SwiftUI

// MARK: - 打开文件夹设置

struct OpenFolderSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customFolderPath = ""

    private let presetFolders: [FolderPreset] = [
        FolderPreset(name: "open_folder.desktop", path: "~/Desktop", icon: "desktopcomputer"),
        FolderPreset(name: "open_folder.downloads", path: "~/Downloads", icon: "arrow.down.circle.fill"),
        FolderPreset(name: "open_folder.documents", path: "~/Documents", icon: "doc.fill"),
        FolderPreset(name: "open_folder.projects", path: "~/Projects", icon: "folder.fill"),
        FolderPreset(name: "open_folder.applications", path: "~/Applications", icon: "app.fill"),
        FolderPreset(name: "open_folder.pictures", path: "~/Pictures", icon: "photo.fill"),
        FolderPreset(name: "open_folder.music", path: "~/Music", icon: "music.note"),
        FolderPreset(name: "open_folder.movies", path: "~/Movies", icon: "film.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("open_folder.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(localized("open_folder.desc"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            let enabledFolders = getEnabledFolders()

            if !enabledFolders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized("common.enabled"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(enabledFolders) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "folder.fill" : item.icon,
                                name: DefaultItemNameMapping.localizedItemName(item.name),
                                onEdit: { onEdit(.folder(item)) },
                                onDelete: { deleteFolder(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加
            Text(localized("open_folder.preset_folders"))
                .font(.headline)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(getAvailableFolders()) { folder in
                        AddableChip(
                            icon: folder.icon,
                            name: localized(folder.name),
                            onAdd: { addFolder(folder) }
                        )
                    }
                }
            }

            Divider()

            // 自定义文件夹
            Text(localized("open_folder.add_custom"))
                .font(.headline)

            HStack {
                TextField(localized("open_folder.folder_path_placeholder"), text: $customFolderPath)
                    .textFieldStyle(.roundedBorder)

                Button(localized("open_folder.browse")) {
                    browseFolder()
                }
            }

            Button(localized("open_folder.add_folder")) {
                addCustomFolder()
            }
            .disabled(customFolderPath.isEmpty)

            Spacer()
        }
        .padding(20)
    }

    private func getEnabledFolders() -> [CommandItem] {
        let group = config.groups.first { $0.name == "打开文件夹" }
        return group?.items.filter { $0.type == .openFinder } ?? []
    }

    private func getAvailableFolders() -> [FolderPreset] {
        let enabledNames = Set(getEnabledFolders().map { $0.name })
        return presetFolders.filter { !enabledNames.contains($0.name) }
    }

    private func addFolder(_ folder: FolderPreset) {
        ensureGroup(name: "打开文件夹", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "打开文件夹" }) {
            let item = folder.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomFolder() {
        let path = (customFolderPath as NSString).expandingTildeInPath
        let name = URL(fileURLWithPath: path).lastPathComponent

        ensureGroup(name: "打开文件夹", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "打开文件夹" }) {
            let item = CommandItem(name: name, icon: "folder.fill", type: .openFinder, targetPath: path)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customFolderPath = ""
        }
    }

    private func deleteFolder(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "打开文件夹" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            customFolderPath = url.path
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
