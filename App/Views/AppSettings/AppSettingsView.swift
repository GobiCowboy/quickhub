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

// MARK: - 打开应用设置

struct OpenAppSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customAppPath = ""
    @State private var showFilePicker = false

    private let presetApps: [AppPreset] = [
        AppPreset(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", icon: "p.square.fill"),
        AppPreset(name: "Sublime Text", path: "/Applications/Sublime Text.app", icon: "doc.text"),
        AppPreset(name: "Typora", path: "/Applications/Typora.app", icon: "doc.richtext"),
        AppPreset(name: "iTerm", path: "/Applications/iTerm.app", icon: "terminal.fill"),
        AppPreset(name: "Terminal", path: "/Applications/Utilities/Terminal.app", icon: "terminal"),
        AppPreset(name: "Finder", path: "/System/Library/CoreServices/Finder.app", icon: "folder.fill"),
        AppPreset(name: "Safari", path: "/Applications/Safari.app", icon: "safari"),
        AppPreset(name: "Chrome", path: "/Applications/Google Chrome.app", icon: "globe"),
        AppPreset(name: "Docker", path: "/Applications/Docker.app", icon: "shippingbox.fill"),
        AppPreset(name: "Xcode", path: "/Applications/Xcode.app", icon: "hammer.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("打开应用")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择在右键菜单中快速打开的应用")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            let enabledApps = getEnabledApps()

            if !enabledApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(enabledApps) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "app" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.app(item)) },
                                onDelete: { deleteApp(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加
            Text("预设应用")
                .font(.headline)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(getAvailableApps()) { app in
                        AddableChip(
                            icon: app.icon,
                            name: app.name,
                            onAdd: { addApp(app) }
                        )
                    }
                }
            }

            Divider()

            // 自定义应用
            Text("添加自定义应用")
                .font(.headline)

            HStack {
                TextField("应用路径，如 /Applications/xxx.app", text: $customAppPath)
                    .textFieldStyle(.roundedBorder)

                Button("浏览...") {
                    showFilePicker = true
                }
            }

            Button("添加应用") {
                addCustomApp()
            }
            .disabled(customAppPath.isEmpty)

            Spacer()
        }
        .padding(20)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.application]) { result in
            if case .success(let url) = result {
                customAppPath = url.path
            }
        }
    }

    private func getEnabledApps() -> [CommandItem] {
        let group = config.groups.first { $0.name == "常用应用" }
        return group?.items.filter { $0.type == .openApp } ?? []
    }

    private func getAvailableApps() -> [AppPreset] {
        let enabledNames = Set(getEnabledApps().map { $0.name })
        return presetApps.filter { !enabledNames.contains($0.name) }
    }

    private func addApp(_ app: AppPreset) {
        ensureGroup(name: "常用应用", icon: "app")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用应用" }) {
            let item = app.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomApp() {
        let path = customAppPath
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        ensureGroup(name: "常用应用", icon: "app")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用应用" }) {
            let item = CommandItem(name: name, icon: "app", type: .openApp, targetPath: path)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customAppPath = ""
        }
    }

    private func deleteApp(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用应用" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}

// MARK: - 打开文件夹设置

struct OpenFolderSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customFolderPath = ""

    private let presetFolders: [FolderPreset] = [
        FolderPreset(name: "桌面", path: "~/Desktop", icon: "desktopcomputer"),
        FolderPreset(name: "下载", path: "~/Downloads", icon: "arrow.down.circle.fill"),
        FolderPreset(name: "文档", path: "~/Documents", icon: "doc.fill"),
        FolderPreset(name: "项目", path: "~/Projects", icon: "folder.fill"),
        FolderPreset(name: "应用", path: "~/Applications", icon: "app.fill"),
        FolderPreset(name: "图片", path: "~/Pictures", icon: "photo.fill"),
        FolderPreset(name: "音乐", path: "~/Music", icon: "music.note"),
        FolderPreset(name: "影片", path: "~/Movies", icon: "film.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("打开文件夹")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择在右键菜单中显示的快捷目录")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            let enabledFolders = getEnabledFolders()

            if !enabledFolders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(enabledFolders) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "folder.fill" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.folder(item)) },
                                onDelete: { deleteFolder(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加
            Text("预设目录")
                .font(.headline)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(getAvailableFolders()) { folder in
                        AddableChip(
                            icon: folder.icon,
                            name: folder.name,
                            onAdd: { addFolder(folder) }
                        )
                    }
                }
            }

            Divider()

            // 自定义文件夹
            Text("添加自定义文件夹")
                .font(.headline)

            HStack {
                TextField("文件夹路径，如 ~/MyFolder", text: $customFolderPath)
                    .textFieldStyle(.roundedBorder)

                Button("浏览...") {
                    browseFolder()
                }
            }

            Button("添加文件夹") {
                addCustomFolder()
            }
            .disabled(customFolderPath.isEmpty)

            Spacer()
        }
        .padding(20)
    }

    private func getEnabledFolders() -> [CommandItem] {
        let group = config.groups.first { $0.name == "常用目录" }
        return group?.items.filter { $0.type == .openFinder } ?? []
    }

    private func getAvailableFolders() -> [FolderPreset] {
        let enabledNames = Set(getEnabledFolders().map { $0.name })
        return presetFolders.filter { !enabledNames.contains($0.name) }
    }

    private func addFolder(_ folder: FolderPreset) {
        ensureGroup(name: "常用目录", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用目录" }) {
            let item = folder.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomFolder() {
        let path = (customFolderPath as NSString).expandingTildeInPath
        let name = URL(fileURLWithPath: path).lastPathComponent

        ensureGroup(name: "常用目录", icon: "folder")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用目录" }) {
            let item = CommandItem(name: name, icon: "folder.fill", type: .openFinder, targetPath: path)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customFolderPath = ""
        }
    }

    private func deleteFolder(_ item: CommandItem) {
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用目录" }) {
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

// MARK: - 命令行设置

struct ShellCommandSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customCommand = ""
    @State private var customCommandName = ""

    private let presetCommands: [ShellPreset] = [
        ShellPreset(name: "Git 状态", command: "git status", icon: "arrow.triangle.branch", openTerminal: true),
        ShellPreset(name: "Git 拉取", command: "git pull", icon: "arrow.down.circle", openTerminal: true),
        ShellPreset(name: "Git 推送", command: "git push", icon: "arrow.up.circle", openTerminal: true),
        ShellPreset(name: "Git 分支", command: "git branch -a", icon: "arrow.triangle.branch", openTerminal: true),
        ShellPreset(name: "Docker 容器", command: "docker ps", icon: "shippingbox.fill", openTerminal: true),
        ShellPreset(name: "Docker 镜像", command: "docker images", icon: "shippingbox", openTerminal: true),
        ShellPreset(name: "NPM 依赖", command: "npm install", icon: "cube.box", openTerminal: true),
        ShellPreset(name: "PIP 列表", command: "pip list", icon: "cube.box.fill", openTerminal: true),
        ShellPreset(name: "复制路径", command: "echo -n '{path}' | pbcopy", icon: "doc.on.doc", openTerminal: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("命令行工具")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择在右键菜单中显示的命令")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // 已启用
            let enabledCommands = getEnabledCommands()

            if !enabledCommands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已启用", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    FlowLayout(spacing: 8) {
                        ForEach(enabledCommands) { item in
                            EnabledChip(
                                icon: item.icon.isEmpty ? "command" : item.icon,
                                name: item.name,
                                onEdit: { onEdit(.shell(item)) },
                                onDelete: { deleteCommand(item) }
                            )
                        }
                    }
                }

                Divider()
            }

            // 可添加
            Text("预设命令")
                .font(.headline)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(getAvailableCommands()) { cmd in
                        AddableChip(
                            icon: cmd.icon,
                            name: cmd.name,
                            onAdd: { addCommand(cmd) }
                        )
                    }
                }
            }

            Divider()

            // 自定义命令
            Text("添加自定义命令")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("命令名称", text: $customCommandName)
                    .textFieldStyle(.roundedBorder)

                TextField("命令内容，如: git status", text: $customCommand)
                    .textFieldStyle(.roundedBorder)

                Text("提示: 使用 {path} 表示选中文件路径，{dir} 表示目录")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("添加命令") {
                    addCustomCommand()
                }
                .disabled(customCommand.isEmpty || customCommandName.isEmpty)
            }

            Spacer()
        }
        .padding(20)
    }

    private func getEnabledCommands() -> [CommandItem] {
        let group = config.groups.first { $0.name == "终端命令" }
        return group?.items.filter { $0.type == .shell } ?? []
    }

    private func getAvailableCommands() -> [ShellPreset] {
        let enabledNames = Set(getEnabledCommands().map { $0.name })
        return presetCommands.filter { !enabledNames.contains($0.name) }
    }

    private func addCommand(_ cmd: ShellPreset) {
        ensureGroup(name: "终端命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            let item = cmd.toCommandItem()
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func addCustomCommand() {
        ensureGroup(name: "终端命令", icon: "terminal")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
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
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "终端命令" }) {
            config.groups[groupIndex].items.removeAll { $0.id == item.id }
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
        }
    }

    private func ensureGroup(name: String, icon: String) {
        if !config.groups.contains(where: { $0.name == name }) {
            config.groups.append(CommandGroup(name: name, icon: icon))
        }
    }
}

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
                Text("编辑项目")
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
                        Text("名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("输入名称", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 图标
                    VStack(alignment: .leading, spacing: 8) {
                        Text("图标")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("SF Symbol 名称", text: $icon)
                                .textFieldStyle(.roundedBorder)
                            Button("浏览...") {
                                openIconPicker()
                            }
                        }
                        Text("示例: doc.text, terminal, folder.fill, swift")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 类型特定字段
                    switch item {
                    case .template:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("文件扩展名")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("如: txt, md, swift", text: $fileExtension)
                                .textFieldStyle(.roundedBorder)
                        }

                    case .folderItem:
                        EmptyView()

                    case .app, .folder:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("路径")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("文件或文件夹路径", text: $targetPath)
                                .textFieldStyle(.roundedBorder)
                        }

                    case .shell:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("命令")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $command)
                                .frame(height: 100)
                                .font(.system(.body, design: .monospaced))
                                .border(Color.secondary.opacity(0.3), width: 1)
                            Text("占位符: {path}, {dir}, {filename}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Toggle("在终端中执行", isOn: $openInTerminal)
                    }
                }
                .padding(20)
            }

            Divider()

            // 按钮栏
            HStack {
                Button("删除") {
                    deleteItem()
                    dismiss()
                }
                .foregroundColor(.red)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
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
                }

                config.groups[groupIndex].items[itemIndex] = updatedItem
                StorageService.shared.saveConfig(config)
                return
            }
        }
    }
}

// MARK: - 通用设置

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @State private var hotkey = "Cmd+Shift+P"

    var body: some View {
        Form {
            Section("启动") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
            }

            Section("通知") {
                Toggle("执行命令后显示通知", isOn: $showNotifications)
            }

            Section("快捷键") {
                HStack {
                    Text("打开面板")
                    Spacer()
                    Text(hotkey)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Link("GitHub 项目", destination: URL(string: "https://github.com/your-repo")!)

                Link("问题反馈", destination: URL(string: "https://github.com/your-repo/issues")!)
            }

            Section("高级") {
                Button("打开配置文件目录") {
                    openConfigDirectory()
                }

                Button("重置所有设置为默认") {
                    resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private func openConfigDirectory() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/rightclickx")
        NSWorkspace.shared.open(path)
    }

    private func resetToDefaults() {
        StorageService.shared.saveConfig(AppConfig(groups: []))
        ConfigObserver.shared.refresh()
    }
}

// MARK: - 数据类型

struct FileTemplatePreset: Identifiable {
    let id = UUID()
    let name: String
    let ext: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .createFile, template: "", fileExtension: ext)
    }
}

struct AppPreset: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .openApp, targetPath: path)
    }
}

struct FolderPreset: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .openFinder, targetPath: path)
    }
}

struct ShellPreset: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let icon: String
    let openTerminal: Bool

    func toCommandItem() -> CommandItem {
        CommandItem(name: name, icon: icon, type: .shell, command: command, openInTerminal: openTerminal)
    }
}

#Preview {
    AppSettingsView()
        .frame(width: 900, height: 700)
}
