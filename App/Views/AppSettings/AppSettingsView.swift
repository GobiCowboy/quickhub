import SwiftUI

// MARK: - 设置视图

struct AppSettingsView: View {
    @State private var selectedCategory: SettingsCategory = .newFile
    @State private var config = StorageService.shared.loadConfig()
    @State private var editingItem: EditableItem?
    @State private var refreshTrigger = false  // 用于触发视图刷新

    var body: some View {
        HSplitView {
            // 左侧分类导航
            List(selection: $selectedCategory) {
                ForEach(SettingsCategory.allCases, id: \.self) { category in
                    Label(category.title, systemImage: category.icon)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 160)

            // 右侧内容区
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
            .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
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

    var id: UUID {
        switch self {
        case .template(let item): return item.id
        case .folderItem(let item): return item.id
        case .app(let item): return item.id
        case .folder(let item): return item.id
        case .shell(let item): return item.id
        case .copyPath(let item): return item.id
        case .bitwardenSearch(let item): return item.id
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
