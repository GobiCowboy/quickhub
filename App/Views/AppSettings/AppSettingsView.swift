import SwiftUI

struct AppSettingsView: View {
    @State private var selectedCategory: SettingsCategory = .newFile
    @State private var config = StorageService.shared.loadConfig()
    @State private var editingItem: EditableItem?

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
    }
}

// MARK: - 可编辑项

enum EditableItem: Identifiable, Equatable {
    case template(CommandItem)
    case folderItem(CommandItem)  // 新建文件夹
    case app(CommandItem)
    case folder(CommandItem)
    case shell(CommandItem)

    var id: UUID {
        switch self {
        case .template(let item): return item.id
        case .folderItem(let item): return item.id
        case .app(let item): return item.id
        case .folder(let item): return item.id
        case .shell(let item): return item.id
        }
    }
}

// MARK: - 设置分类

enum SettingsCategory: String, CaseIterable {
    case newFile = "new_file"
    case openApp = "open_app"
    case openFolder = "open_folder"
    case shell = "shell"
    case general = "general"

    var title: String {
        switch self {
        case .newFile: return "新建文件"
        case .openApp: return "打开应用"
        case .openFolder: return "打开文件夹"
        case .shell: return "命令行"
        case .general: return "通用设置"
        }
    }

    var icon: String {
        switch self {
        case .newFile: return "doc.badge.plus"
        case .openApp: return "app"
        case .openFolder: return "folder"
        case .shell: return "terminal"
        case .general: return "gear"
        }
    }
}

#Preview {
    AppSettingsView()
        .frame(width: 900, height: 700)
}
