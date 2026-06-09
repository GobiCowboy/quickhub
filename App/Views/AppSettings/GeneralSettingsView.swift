import SwiftUI
import ServiceManagement
import AppKit
import Carbon

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @State private var interceptRightClick = false
    @StateObject private var hotkeyRecorder = HotkeyRecorderViewModel()
    @StateObject private var localeManager = LocaleManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPageHeader(
                    title: localized("settings.category.general"),
                    subtitle: localized("settings.general.desc"),
                    icon: "gear"
                )

                SettingsSurface(title: localized("settings.general.section.language"), systemImage: "globe") {
                    SettingsValueRow(title: localized("settings.general.language"), icon: "character.bubble") {
                        Picker("", selection: $localeManager.currentLanguage) {
                            ForEach(LocaleManager.Language.allCases, id: \.self) { language in
                                Text(language.rawValue).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: localeManager.currentLanguage) { _ in
                            // 语言切换后刷新视图
                        }
                    }
                }

                SettingsSurface(title: localized("settings.general.section.startup"), systemImage: "power") {
                    SettingsToggleRow(
                        title: localized("settings.general.launch_at_login"),
                        icon: "arrow.up.forward.app",
                        isOn: $launchAtLogin
                    ) {
                        saveSettings()
                    }
                }

                SettingsSurface(title: localized("settings.general.section.notifications"), systemImage: "bell") {
                    SettingsToggleRow(
                        title: localized("settings.general.show_notifications"),
                        icon: "bell.badge",
                        isOn: $showNotifications
                    ) {
                        saveSettings()
                    }
                }

                SettingsSurface(title: localized("settings.general.section.shortcut"), systemImage: "keyboard") {
                    VStack(spacing: 8) {
                        SettingsToggleRow(
                            title: localized("settings.general.intercept_right_click"),
                            icon: "cursorarrow.click.2",
                            isOn: $interceptRightClick
                        ) {
                            saveSettings()
                        }

                        Divider()

                        SettingsValueRow(title: localized("settings.general.open_panel"), icon: "keyboard.badge.eye") {
                            HotkeyRecorderView(hotkey: $hotkeyRecorder.hotkey) {
                                saveSettings()
                            }
                        }
                    }
                }

                SettingsSurface(title: localized("settings.general.section.about"), systemImage: "info.circle") {
                    VStack(spacing: 8) {
                        SettingsValueRow(title: localized("settings.general.version"), icon: "app.badge") {
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.6")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        SettingsLinkRow(title: localized("settings.general.github"), icon: "link", url: URL(string: "https://github.com/your-repo")!)

                        Divider()

                        SettingsLinkRow(title: localized("settings.general.feedback"), icon: "exclamationmark.bubble", url: URL(string: "https://github.com/your-repo/issues")!)
                    }
                }

                SettingsSurface(title: localized("settings.general.section.advanced"), systemImage: "wrench.and.screwdriver") {
                    VStack(spacing: 8) {
                        SettingsActionRow(
                            title: localized("settings.general.open_config_dir"),
                            icon: "folder"
                        ) {
                            openConfigDirectory()
                        }

                        Divider()

                        SettingsActionRow(
                            title: localized("settings.general.reset_all"),
                            icon: "arrow.counterclockwise"
                        ) {
                            resetToDefaults()
                        }
                    }
                }
            }
            .padding(22)
        }
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        let settings = StorageService.shared.loadConfig().settings
        hotkeyRecorder.hotkey = settings.hotkey ?? HotkeyConfiguration.defaultHotkey
        launchAtLogin = settings.launchAtLogin
        showNotifications = settings.showNotifications
        interceptRightClick = settings.interceptRightClick
    }

    private func saveSettings() {
        var config = StorageService.shared.loadConfig()
        config.settings.hotkey = hotkeyRecorder.hotkey
        config.settings.launchAtLogin = launchAtLogin
        config.settings.showNotifications = showNotifications
        config.settings.interceptRightClick = interceptRightClick
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

private struct SettingsValueRow<Trailing: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            trailing
        }
        .padding(.vertical, 3)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let onChange: () -> Void

    var body: some View {
        SettingsValueRow(title: title, icon: icon) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _ in
                    onChange()
                }
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsValueRow(title: title, icon: icon) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let icon: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            SettingsValueRow(title: title, icon: icon) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
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
