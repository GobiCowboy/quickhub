import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @StateObject private var hotkeyRecorder = HotkeyRecorderViewModel()

    var body: some View {
        Form {
            Section("启动") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        saveSettings()
                    }
            }

            Section("通知") {
                Toggle("执行命令后显示通知", isOn: $showNotifications)
                    .onChange(of: showNotifications) { _ in
                        saveSettings()
                    }
            }

            Section("快捷键") {
                HStack {
                    Text("打开面板")
                    Spacer()
                    HotkeyRecorderView(hotkey: $hotkeyRecorder.hotkey)
                        .onChange(of: hotkeyRecorder.hotkey) { _ in
                            saveSettings()
                        }
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
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        let settings = StorageService.shared.loadConfig().settings
        hotkeyRecorder.hotkey = settings.hotkey
        launchAtLogin = settings.launchAtLogin
        showNotifications = settings.showNotifications
    }

    private func saveSettings() {
        var config = StorageService.shared.loadConfig()
        config.settings.hotkey = hotkeyRecorder.hotkey
        config.settings.launchAtLogin = launchAtLogin
        config.settings.showNotifications = showNotifications
        StorageService.shared.saveConfig(config)

        // 更新开机自动启动状态
        updateLaunchAtLogin()

        // 通知 AppDelegate 重新注册快捷键
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("设置开机启动失败: \(error.localizedDescription)")
            // 同步 UI 状态
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func openConfigDirectory() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/rightclickx")
        NSWorkspace.shared.open(path)
    }

    private func resetToDefaults() {
        StorageService.shared.saveConfig(AppConfig(groups: []))
        ConfigObserver.shared.refresh()
        loadSettings()
    }
}

// MARK: - 快捷键录制视图模型
class HotkeyRecorderViewModel: ObservableObject {
    @Published var hotkey: HotkeyConfiguration?

    init() {}
}

// MARK: - 通知名称
extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}
