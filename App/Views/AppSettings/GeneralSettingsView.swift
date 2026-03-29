import SwiftUI

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
