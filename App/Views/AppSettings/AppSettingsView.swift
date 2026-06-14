import SwiftUI

// MARK: - 设置视图

struct AppSettingsView: View {
    @State private var selectedCategory: SettingsCategory = .newFile
    @State private var config = StorageService.shared.loadConfig()
    @State private var editingItem: EditableItem?
    @State private var refreshTrigger = false  // 用于触发视图刷新

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .opacity(0.65)

            detailPane
        }
        .frame(minWidth: 1020, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingItem) { item in
            ItemEditorSheet(item: item, onSave: {
                config = StorageService.shared.loadConfig()
                ConfigObserver.shared.refresh()
            })
        }
        .onAppear {
            // 监听语言切换
            NotificationCenter.default.addObserver(
                forName: .languageChanged,
                object: nil,
                queue: .main
            ) { [self] _ in
                // 重新加载配置以刷新视图
                config = StorageService.shared.loadConfig()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("QuickHub", systemImage: "command.circle.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text(localized("settings.subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            List(selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases, id: \.self) { category in
                    Label(category.title, systemImage: category.icon)
                        .font(.system(size: 13, weight: .medium))
                        .tag(category)
                        .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .frame(width: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var detailPane: some View {
        Group {
            switch selectedCategory {
            case .newFile:
                NewFileSettingsView(config: $config, onEdit: { editingItem = $0 })
            case .openApp:
                OpenAppSettingsView(config: $config, onEdit: { editingItem = $0 })
            case .openFolder:
                OpenFolderSettingsView(config: $config, onEdit: { editingItem = $0 })
            case .shell:
                ShellCommandSettingsView(config: $config, onEdit: { editingItem = $0 })
            case .menuSort:
                MenuSortSettingsView(config: $config)
            case .general:
                GeneralSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct SettingsSurface<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SettingsChipSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
    }
}

struct SettingsPasteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(localized("common.paste"), systemImage: "doc.on.clipboard")
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.borderless)
        .help(localized("common.paste_from_clipboard"))
    }
}

struct CommandSettingRow: View {
    let item: CommandItem
    let name: String
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            CommandIconChip(item: item, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(CommandVisualStyle.hint(for: item))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - 可编辑项

enum EditableItem: Identifiable, Equatable {
    case template(CommandItem)
    case folderItem(CommandItem)  // 新建文件夹
    case app(CommandItem)
    case folder(CommandItem)
    case shell(CommandItem)
    case copyPath(CommandItem)
    case bitwardenSearch(CommandItem)
    case genericCommand(CommandItem)  // 剪切/复制/粘贴/删除/重命名/用其他程序打开/共享

    var id: UUID {
        switch self {
        case .template(let item): return item.id
        case .folderItem(let item): return item.id
        case .app(let item): return item.id
        case .folder(let item): return item.id
        case .shell(let item): return item.id
        case .copyPath(let item): return item.id
        case .bitwardenSearch(let item): return item.id
        case .genericCommand(let item): return item.id
        }
    }
}

// MARK: - 设置分类

enum SettingsCategory: String, CaseIterable {
    case newFile = "new_file"
    case openFolder = "open_folder"
    case openApp = "open_app"
    case shell = "shell"
    case menuSort = "menu_sort"
    case general = "general"

    var title: String {
        switch self {
        case .newFile: return localized("settings.category.new_file")
        case .openFolder: return localized("settings.category.open_folder")
        case .openApp: return localized("settings.category.open_app")
        case .shell: return localized("settings.category.shell")
        case .menuSort: return localized("settings.category.menu_sort")
        case .general: return localized("settings.category.general")
        }
    }

    var icon: String {
        switch self {
        case .newFile: return "doc.badge.plus"
        case .openFolder: return "folder"
        case .openApp: return "app"
        case .shell: return "terminal"
        case .menuSort: return "list.bullet"
        case .general: return "gear"
        }
    }
}

#Preview {
    AppSettingsView()
        .frame(width: 900, height: 700)
}
