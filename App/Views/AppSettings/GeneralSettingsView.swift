import SwiftUI
import ServiceManagement
import AppKit
import Carbon

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @StateObject private var hotkeyRecorder = HotkeyRecorderViewModel()
    @StateObject private var localeManager = LocaleManager.shared

    var body: some View {
        Form {
            Section(localized("settings.general.section.language")) {
                Picker(localized("settings.general.language"), selection: $localeManager.currentLanguage) {
                    ForEach(LocaleManager.Language.allCases, id: \.self) { language in
                        Text(language.rawValue).tag(language)
                    }
                }
                .onChange(of: localeManager.currentLanguage) { _ in
                    // 语言切换后刷新视图
                }
            }

            Section(localized("settings.general.section.startup")) {
                Toggle(localized("settings.general.launch_at_login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        saveSettings()
                    }
            }

            Section(localized("settings.general.section.notifications")) {
                Toggle(localized("settings.general.show_notifications"), isOn: $showNotifications)
                    .onChange(of: showNotifications) { _ in
                        saveSettings()
                    }
            }

            Section(localized("settings.general.section.shortcut")) {
                HStack {
                    Text(localized("settings.general.open_panel"))
                    Spacer()
                    HotkeyRecorderView(hotkey: $hotkeyRecorder.hotkey) {
                        saveSettings()
                    }
                }
            }

            Section(localized("settings.general.section.about")) {
                HStack {
                    Text(localized("settings.general.version"))
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Link(localized("settings.general.github"), destination: URL(string: "https://github.com/your-repo")!)

                Link(localized("settings.general.feedback"), destination: URL(string: "https://github.com/your-repo/issues")!)
            }

            Section(localized("settings.general.section.advanced")) {
                Button(localized("settings.general.open_config_dir")) {
                    openConfigDirectory()
                }

                Button(localized("settings.general.reset_all")) {
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
        hotkeyRecorder.hotkey = settings.hotkey ?? HotkeyConfiguration.defaultHotkey
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
            print(localized("settings.general.launch_at_login_failed", with: error.localizedDescription))
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
        StorageService.shared.saveConfig(AppConfig(groups: StorageService.defaultGroups()))
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
