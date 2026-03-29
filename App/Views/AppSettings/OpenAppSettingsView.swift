import SwiftUI

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
