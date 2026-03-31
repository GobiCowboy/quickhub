import SwiftUI

@main
struct QuickHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 状态管理：是否已看过引导页
    @AppStorage("hasSeenWelcomeV1") var hasSeenWelcome = false

    var body: some Scene {
        // 主应用设置点
        Settings { EmptyView() }
        
        // 设置窗口 - macOS 13 兼容性写法
        WindowGroup("QuickHub 设置", id: "settings") {
            AppSettingsView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .handlesExternalEvents(matching: ["settings"])
        
        // 欢迎引导窗口 - 利用 WindowGroup 的 Scene 管理
        WindowGroup("欢迎使用 QuickHub", id: "welcome") {
            if !hasSeenWelcome {
                WelcomeView {
                    hasSeenWelcome = true
                    // 直接在 AppKit 层面找到“欢迎”窗口并关闭它
                    NSApp.windows.filter { $0.title == "欢迎使用 QuickHub" }.forEach { $0.close() }
                }
            } else {
                // 如果已经看过，这个 Scene 保持为空，防止重复开启
                Color.clear.frame(width: 0, height: 0)
                    .onAppear {
                        // 如果因为某种原因通过 URL 唤醒了已失效的引导，直接关闭对应窗口
                        NSApp.windows.filter { $0.title == "欢迎使用 QuickHub" }.forEach { $0.close() }
                    }
            }
        }
        .handlesExternalEvents(matching: ["welcome"])
    }
}
