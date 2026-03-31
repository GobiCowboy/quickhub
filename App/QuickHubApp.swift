import SwiftUI

@main
struct QuickHubApp: App {
    // 适配器模式，通过 SwiftUI 生命周期自动启动和持有 AppDelegate，防止内存回收
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // UIElement 应用不需要默认窗口，故使用 Settings 占位（由于 LSUIElement 为 true，这并不会正常显示在 Dock）
        Settings {
            EmptyView()
        }
    }
}
