import SwiftUI

// MARK: - 打开文件夹设置

struct OpenFolderSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customFolderName = ""
    @State private var customFolderPath = ""
    @State private var customIcon = "folder"
    @State private var showIconPicker = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPageHeader(
                    title: localized("open_folder.title"),
                    subtitle: localized("open_folder.desc"),
                    icon: "folder"
                )

                let enabledFolders = getEnabledFolders()

                SettingsSurface(title: localized("common.enabled"), systemImage: "checkmark.circle.fill") {
                    if enabledFolders.isEmpty {
                        Text(localized("settings.empty.enabled"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(enabledFolders) { item in
                                EnabledChip(
                                    icon: item.icon.isEmpty ? "folder.fill" : item.icon,
                                    name: DefaultItemNameMapping.localizedItemName(item.name),
                                    item: item,
                                    onEdit: { onEdit(.folder(item)) },
                                    onDelete: { deleteFolder(item) }
                                )
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("open_folder.preset_folders"), systemImage: "plus.circle") {
                    FlowLayout(spacing: 8) {
                        ForEach(getAvailableFolders()) { folder in
                            AddableChip(
                                icon: folder.icon,
                                name: localized(folder.name),
                                item: folder.toCommandItem(),
                                onAdd: { addFolder(folder) }
                            )
                        }
                    }
                }

                SettingsSurface(title: localized("open_folder.add_custom"), systemImage: "folder.badge.plus") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 图标选择
                        Button(action: { showIconPicker = true }) {
                            HStack(spacing: 8) {
                                if customIcon.hasPrefix("openmoji/"), let image = loadBundleImage(customIcon) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                } else if customIcon.hasPrefix("/"), let image = NSImage(contentsOfFile: customIcon) {
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
                            TextField(localized("editor.field.name_placeholder"), text: $customFolderName)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customFolderName = content
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField(localized("open_folder.folder_path_placeholder"), text: $customFolderPath)
                                .textFieldStyle(.roundedBorder)
                            SettingsPasteButton {
                                if let content = NSPasteboard.general.string(forType: .string) {
                                    customFolderPath = content
                                }
                            }
                            Button(localized("open_folder.browse")) {
                                browseFolder()
                            }
                        }

                        HStack {
                            Spacer()
                            Button(localized("open_folder.add_folder")) {
                                addCustomFolder()
                            }
                            .disabled(customFolderPath.isEmpty)
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
        let path = (customFolderPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        let trimmedName = customFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : trimmedName

        ensureGroup(name: "打开文件夹", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "打开文件夹" }) {
            let item = CommandItem(name: name, icon: customIcon, type: .openFinder, targetPath: path)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customFolderName = ""
            customFolderPath = ""
            customIcon = "folder"
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
            if customFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                customFolderName = url.lastPathComponent
            }
        }
    }

    private func loadBundleImage(_ name: String) -> NSImage? {
        let pathComponent = name.hasPrefix("openmoji/") ? String(name.dropFirst(9)) : name
        let fileName = (pathComponent as NSString).deletingPathExtension
        let ext = (pathComponent as NSString).pathExtension.isEmpty ? "png" : (name as NSString).pathExtension
        if let path = Bundle.main.path(forResource: fileName, ofType: ext) {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}
