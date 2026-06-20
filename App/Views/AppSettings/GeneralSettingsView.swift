import SwiftUI
import ServiceManagement
import AppKit

struct GeneralSettingsView: View {
    private let highlightRightClickToggle: Bool
    @State private var launchAtLogin = false
    @State private var showMenuBarIcon = true
    @State private var showNotifications = false
    @State private var hotkeyEnabled = false
    @State private var interceptRightClick = false
    @State private var rightClickDefaultAction: RightClickDefaultAction = .quickHub
    @State private var updateStatus: UpdateStatus = .idle
    @State private var showUpdateAlert = false
    @State private var pendingVersion: String = ""
    @State private var pendingAssetURL: String = ""
    @State private var downloadProgress: Double = 0
    @StateObject private var localeManager = LocaleManager.shared
    @State private var rightClickHighlightPulse = false
    @State private var rightClickGuideVisible = false

    init(highlightRightClickToggle: Bool = false) {
        self.highlightRightClickToggle = highlightRightClickToggle
    }

    private enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate
        case downloading
        case installing
        case done
        case failed

        static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate),
                 (.downloading, .downloading), (.installing, .installing),
                 (.done, .done), (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsPageHeader(
                        title: localized("settings.category.general"),
                        subtitle: localized("settings.general.desc"),
                        icon: "gear"
                    )

                    if rightClickGuideVisible {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.point.up.left.fill")
                                .foregroundStyle(Color.accentColor)
                                .padding(.top, 1)

                            Text("先在这里开启自定义右键行为，然后再选右键面板默认动作。")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                    }

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
                        VStack(spacing: 8) {
                            SettingsToggleRow(
                                title: localized("settings.general.launch_at_login"),
                                icon: "arrow.up.forward.app",
                                isOn: $launchAtLogin
                            ) {
                                saveSettings()
                            }

                            Divider()

                            SettingsToggleRow(
                                title: localized("settings.general.show_menu_bar_icon"),
                                icon: "menubar.rectangle",
                                isOn: $showMenuBarIcon
                            ) {
                                saveSettings()
                            }
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
                                title: localized("settings.general.enable_global_hotkey"),
                                icon: "keyboard.badge.eye",
                                isOn: $hotkeyEnabled
                            ) {
                                saveSettings()
                            }

                            if hotkeyEnabled {
                                SettingsValueRow(title: localized("settings.general.open_panel"), icon: "command") {
                                    Text("⌥ Option + Q")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Divider()
                            }

                            SettingsToggleRow(
                                title: localized("settings.general.intercept_right_click"),
                                icon: "cursorarrow.click.2",
                                isOn: $interceptRightClick,
                                onChange: {
                                    saveSettings()
                                },
                                isHighlighted: highlightRightClickToggle,
                                highlightPulse: rightClickHighlightPulse
                            )
                            .id("general.intercept_right_click")

                            if interceptRightClick {
                                SettingsValueRow(
                                    title: localized("settings.general.right_click_default_action"),
                                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right"
                                ) {
                                    Picker("", selection: $rightClickDefaultAction) {
                                        Text(localized("settings.general.right_click_action.quickhub"))
                                            .tag(RightClickDefaultAction.quickHub)
                                        Text(localized("settings.general.right_click_action.system"))
                                            .tag(RightClickDefaultAction.systemNative)
                                    }
                                    .labelsHidden()
                                    .frame(width: 180)
                                    .onChange(of: rightClickDefaultAction) { _ in
                                        saveSettings()
                                    }
                                }

                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.blue)
                                        .frame(width: 22)

                                    Text(rightClickHint)
                                        .font(.system(size: 12))

                                    Spacer()
                                }

                                Divider()
                            }
                        }
                    }

                    SettingsSurface(title: localized("settings.general.section.about"), systemImage: "info.circle") {
                        VStack(spacing: 8) {
                            SettingsValueRow(title: localized("settings.general.version"), icon: "app.badge") {
                                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            SettingsLinkRow(title: localized("settings.general.github"), icon: "link", url: URL(string: "https://github.com/GobiCowboy/quickhub")!)

                            Divider()

                            SettingsLinkRow(title: localized("settings.general.feedback"), icon: "exclamationmark.bubble", url: URL(string: "https://github.com/GobiCowboy/quickhub/issues")!)

                            Divider()

                            SettingsActionRow(
                                title: updateButtonTitle,
                                icon: "arrow.down.circle"
                            ) {
                                checkForUpdates()
                            }

                            if updateStatus != .idle {
                                updateStatusView
                            }
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
                if highlightRightClickToggle {
                    rightClickGuideVisible = true
                    rightClickHighlightPulse = false
                    DispatchQueue.main.async {
                        proxy.scrollTo("general.intercept_right_click", anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            rightClickHighlightPulse = true
                        }
                    }
                } else {
                    rightClickGuideVisible = false
                    rightClickHighlightPulse = false
                }
            }
        }
        .alert(localized("settings.general.update_confirm_title"), isPresented: $showUpdateAlert) {
            Button(localized("settings.general.update_now")) {
                downloadAndInstall()
            }
            Button(localized("settings.general.update_later"), role: .cancel) {
                updateStatus = .idle
            }
        } message: {
            Text(localized("settings.general.update_confirm_message", with: pendingVersion))
        }
    }

    private func loadSettings() {
        let settings = StorageService.shared.loadConfig().settings
        hotkeyEnabled = !(settings.hotkey?.isEmpty ?? true)
        launchAtLogin = settings.launchAtLogin
        showMenuBarIcon = settings.showMenuBarIcon
        showNotifications = settings.showNotifications
        interceptRightClick = settings.interceptRightClick
        rightClickDefaultAction = settings.rightClickDefaultAction
    }

    private func saveSettings() {
        var config = StorageService.shared.loadConfig()
        config.settings.hotkey = hotkeyEnabled ? HotkeyConfiguration.defaultHotkey : nil
        config.settings.launchAtLogin = launchAtLogin
        config.settings.showMenuBarIcon = showMenuBarIcon
        config.settings.showNotifications = showNotifications
        config.settings.interceptRightClick = interceptRightClick
        config.settings.rightClickDefaultAction = rightClickDefaultAction
        StorageService.shared.saveConfig(config)

        // 更新开机自动启动状态
        updateLaunchAtLogin()
        AppDelegate.shared?.updateStatusItemVisibility()

        // 通知 AppDelegate 重新注册快捷键
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }

    private var updateButtonTitle: String {
        switch updateStatus {
        case .checking:
            return localized("settings.general.checking_update")
        default:
            return localized("settings.general.check_update")
        }
    }

    private var rightClickHint: String {
        switch rightClickDefaultAction {
        case .quickHub:
            return localized("settings.general.right_click_hint_quickhub_default")
        case .systemNative:
            return localized("settings.general.right_click_hint_system_default")
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        HStack(spacing: 6) {
            switch updateStatus {
            case .upToDate:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(localized("settings.general.update_up_to_date"))
                    .font(.system(size: 12))
            case .downloading:
                ProgressView(value: downloadProgress)
                    .frame(width: 120)
                Text(localized("settings.general.downloading_update"))
                    .font(.system(size: 12))
            case .installing:
                ProgressView()
                    .controlSize(.small)
                Text(localized("settings.general.installing_update"))
                    .font(.system(size: 12))
            case .done:
                ProgressView()
                    .controlSize(.small)
                Text(localized("settings.general.update_done"))
                    .font(.system(size: 12))
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(localized("settings.general.update_download_failed"))
                    .font(.system(size: 12))
            default:
                EmptyView()
            }
        }
        .padding(.leading, 32)
    }

    private func checkForUpdates() {
        updateStatus = .checking
        guard let url = URL(string: "https://api.github.com/repos/GobiCowboy/quickhub/releases/latest") else {
            print("[Update] Invalid URL")
            updateStatus = .failed
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[Update] Network error: \(error.localizedDescription)")
                    updateStatus = .failed
                    return
                }

                guard let data = data else {
                    print("[Update] No data received")
                    updateStatus = .failed
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("[Update] JSON parse failed, response: \(String(data: data, encoding: .utf8) ?? "nil")")
                    updateStatus = .failed
                    return
                }

                guard let tagName = json["tag_name"] as? String else {
                    print("[Update] tag_name not found in JSON: \(json)")
                    updateStatus = .failed
                    return
                }

                guard let assetURL = githubReleaseAssetURL(from: json) else {
                    print("[Update] No suitable zip asset found in release: \(json)")
                    updateStatus = .failed
                    return
                }

                print("[Update] Remote tag: \(tagName)")

                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                print("[Update] Remote: \(remoteVersion), Current: \(currentVersion)")

                if isNewerVersion(remoteVersion, than: currentVersion) {
                    pendingVersion = remoteVersion
                    pendingAssetURL = assetURL.absoluteString
                    showUpdateAlert = true
                } else {
                    updateStatus = .upToDate
                }
            }
        }.resume()
    }

    private func downloadAndInstall() {
        guard let url = URL(string: pendingAssetURL) else {
            updateStatus = .failed
            return
        }

        updateStatus = .downloading
        downloadProgress = 0

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async {
                guard let tempURL, error == nil else {
                    updateStatus = .failed
                    return
                }

                updateStatus = .installing

                let fm = FileManager.default
                let tempDir = fm.temporaryDirectory.appendingPathComponent("quickhub_update_\(UUID().uuidString)")

                do {
                    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

                    let zipURL = tempDir.appendingPathComponent("update.zip")
                    try fm.moveItem(at: tempURL, to: zipURL)

                    // 解压
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                    process.arguments = ["-o", zipURL.path, "-d", tempDir.path]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    try process.run()
                    process.waitUntilExit()

                    guard process.terminationStatus == 0 else {
                        try? fm.removeItem(at: tempDir)
                        updateStatus = .failed
                        return
                    }

                    // 找到解压出来的 .app
                    let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                    guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
                        print("[Update] No .app found in: \(contents.map { $0.lastPathComponent })")
                        try? fm.removeItem(at: tempDir)
                        updateStatus = .failed
                        return
                    }

                    print("[Update] Found app: \(appURL.path)")

                    let destination = Bundle.main.bundleURL.standardizedFileURL

                    // 替换旧版本
                    if fm.fileExists(atPath: destination.path) {
                        // 移到废纸篓，加时间戳避免重名
                        let trashURL = try fm.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                        let timestamp = Int(Date().timeIntervalSince1970)
                        try fm.moveItem(at: destination, to: trashURL.appendingPathComponent("QuickHub-\(timestamp).app"))
                    }

                    try fm.moveItem(at: appURL, to: destination)
                    try? fm.removeItem(at: tempDir)

                    updateStatus = .done

                    // 重启应用
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        relaunchUpdatedApp(at: destination)
                        NSApp.terminate(nil)
                    }
                } catch {
                    print("[Update] Install error: \(error)")
                    try? fm.removeItem(at: tempDir)
                    updateStatus = .failed
                }
            }
        }

        // 监听下载进度
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                downloadProgress = progress.fractionCompleted
            }
        }
        objc_setAssociatedObject(task, "observation", observation, .OBJC_ASSOCIATION_RETAIN)

        task.resume()
    }

    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    private func githubReleaseAssetURL(from json: [String: Any]) -> URL? {
        guard let assets = json["assets"] as? [[String: Any]] else { return nil }

        let preferredAsset = assets.first { asset in
            guard let name = asset["name"] as? String else { return false }
            return name == "QuickHub-arm64.zip"
        } ?? assets.first { asset in
            guard let name = asset["name"] as? String else { return false }
            return name.hasSuffix(".zip")
        }

        guard
            let preferredAsset,
            let downloadURLString = preferredAsset["browser_download_url"] as? String
        else {
            return nil
        }

        return URL(string: downloadURLString)
    }

    private func relaunchUpdatedApp(at appURL: URL) {
        let parentPID = ProcessInfo.processInfo.processIdentifier
        let escapedPath = appURL.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "while kill -0 \(parentPID) 2>/dev/null; do sleep 0.2; done; open -n -a \"\(escapedPath)\""

        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", script]
        try? relaunch.run()
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
        StorageService.shared.saveConfig(AppConfig(groups: StorageService.defaultGroups(), settings: AppSettings()))
        ConfigObserver.shared.refresh()
        loadSettings()
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        updateLaunchAtLogin()
        AppDelegate.shared?.updateStatusItemVisibility()
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
    var isHighlighted: Bool = false
    var highlightPulse: Bool = false

    var body: some View {
        SettingsValueRow(title: title, icon: icon) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _ in
                    onChange()
                }
        }
        .padding(.horizontal, isHighlighted ? 8 : 0)
        .padding(.vertical, isHighlighted ? 6 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(highlightPulse ? 0.12 : 0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHighlighted ? Color.accentColor.opacity(highlightPulse ? 0.95 : 0.35) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: isHighlighted ? Color.accentColor.opacity(highlightPulse ? 0.3 : 0.12) : .clear, radius: 8, x: 0, y: 0)
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

// MARK: - 通知名称
extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}
