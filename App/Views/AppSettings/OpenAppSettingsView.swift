import SwiftUI

// MARK: - 打开应用设置

struct OpenAppSettingsView: View {
    @Binding var config: AppConfig
    var onEdit: (EditableItem) -> Void
    @State private var customAppPath = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    // 按分类组织的预设应用
    private let presetCategories: [(name: String, icon: String, apps: [AppPreset])] = [
        ("办公", "doc.text", [
            AppPreset(name: "Word", path: "/Applications/Microsoft Word.app", icon: "doc.fill"),
            AppPreset(name: "Excel", path: "/Applications/Microsoft Excel.app", icon: "tablecells"),
            AppPreset(name: "PowerPoint", path: "/Applications/Microsoft PowerPoint.app", icon: "chart.bar"),
            AppPreset(name: "Pages", path: "/Applications/Pages.app", icon: "doc.richtext.fill"),
            AppPreset(name: "Numbers", path: "/Applications/Numbers.app", icon: "tablecells.fill"),
            AppPreset(name: "Keynote", path: "/Applications/Keynote.app", icon: "play.rectangle.fill")
        ]),
        ("设计", "paintpalette", [
            AppPreset(name: "Figma", path: "/Applications/Figma.app", icon: "square.and.pencil"),
            AppPreset(name: "Sketch", path: "/Applications/Sketch.app", icon: "pencil.tip"),
            AppPreset(name: "Photoshop", path: "/Applications/Adobe Photoshop 2024/Adobe Photoshop 2024.app", icon: "photo"),
            AppPreset(name: "Illustrator", path: "/Applications/Adobe Illustrator 2024/Adobe Illustrator 2024.app", icon: "pencil.and.outline"),
            AppPreset(name: "Preview", path: "/Applications/Preview.app", icon: "eye"),
            AppPreset(name: "Pixelmator", path: "/Applications/Pixelmator.app", icon: "paintbrush.fill")
        ]),
        ("开发", "chevron.left.forwardslash.chevron.right", [
            AppPreset(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", icon: "p.square.fill"),
            AppPreset(name: "Xcode", path: "/Applications/Xcode.app", icon: "hammer.fill"),
            AppPreset(name: "Sublime Text", path: "/Applications/Sublime Text.app", icon: "doc.text"),
            AppPreset(name: "Typora", path: "/Applications/Typora.app", icon: "doc.richtext"),
            AppPreset(name: "iTerm", path: "/Applications/iTerm.app", icon: "terminal.fill"),
            AppPreset(name: "Terminal", path: "/Applications/Utilities/Terminal.app", icon: "terminal"),
            AppPreset(name: "Docker", path: "/Applications/Docker.app", icon: "shippingbox.fill")
        ]),
        ("视频", "video", [
            AppPreset(name: "VLC", path: "/Applications/VLC.app", icon: "play.rectangle.fill"),
            AppPreset(name: "IINA", path: "/Applications/IINA.app", icon: "play.circle.fill"),
            AppPreset(name: "QuickTime Player", path: "/Applications/QuickTime Player.app", icon: "film"),
            AppPreset(name: "DaVinci Resolve", path: "/Applications/DaVinci Resolve.app", icon: "film.fill")
        ]),
        ("AI", "brain", [
            AppPreset(name: "ChatGPT", path: "/Applications/ChatGPT.app", icon: "bubble.left.fill"),
            AppPreset(name: "Claude", path: "/Applications/Claude.app", icon: "brain"),
            AppPreset(name: "Copilot", path: "/Applications/Copilot.app", icon: "airplane"),
            AppPreset(name: "Perplexity", path: "/Applications/Perplexity.app", icon: "sparkles"),
            AppPreset(name: "Ollama", path: "/Applications/Ollama.app", icon: "cpu")
        ])
    ]

    // 所有预设应用（扁平列表，用于检测）
    private var allPresetApps: [AppPreset] {
        presetCategories.flatMap { $0.apps }
    }

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

            // 错误信息
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("清除") {
                        errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // 可添加 - 按分类展示
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(presetCategories, id: \.name) { category in
                        let availableApps = getAvailableApps(for: category.apps)
                        if !availableApps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(category.name, systemImage: category.icon)
                                    .font(.headline)
                                    .foregroundColor(.accentColor)

                                FlowLayout(spacing: 8) {
                                    ForEach(availableApps) { app in
                                        AddableChip(
                                            icon: app.icon,
                                            name: app.name,
                                            onAdd: { addApp(app) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
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

            Text("提示: 文件位置有误或未下载时，请通过自定义方式设置")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.application]) { result in
            if case .success(let url) = result {
                customAppPath = url.path
            }
        }
        .onAppear {
            checkForMissingApps()
        }
    }

    private func getEnabledApps() -> [CommandItem] {
        let group = config.groups.first { $0.name == "常用应用" }
        return group?.items.filter { $0.type == .openApp } ?? []
    }

    private func getAvailableApps(for apps: [AppPreset]) -> [AppPreset] {
        let enabledNames = Set(getEnabledApps().map { $0.name })
        return apps.filter { !enabledNames.contains($0.name) }
    }

    private func addApp(_ app: AppPreset) {
        // 检查应用是否存在
        if !FileManager.default.fileExists(atPath: app.path) {
            errorMessage = "\(app.name) 文件位置有误或未下载，请通过自定义方式设置"
            return
        }

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

        // 检查应用是否存在
        if !FileManager.default.fileExists(atPath: path) {
            errorMessage = "应用不存在，请检查路径是否正确"
            return
        }

        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        ensureGroup(name: "常用应用", icon: "app")
        if let groupIndex = config.groups.firstIndex(where: { $0.name == "常用应用" }) {
            let item = CommandItem(name: name, icon: "app", type: .openApp, targetPath: path)
            config.groups[groupIndex].items.append(item)
            StorageService.shared.saveConfig(config)
            ConfigObserver.shared.refresh()
            customAppPath = ""
            errorMessage = nil
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

    /// 检查已添加的应用是否存在
    private func checkForMissingApps() {
        let enabledApps = getEnabledApps()
        for app in enabledApps {
            if let targetPath = app.targetPath {
                if !FileManager.default.fileExists(atPath: targetPath) {
                    errorMessage = "\(app.name) 文件位置有误或未下载"
                    return
                }
            }
        }
    }
}
