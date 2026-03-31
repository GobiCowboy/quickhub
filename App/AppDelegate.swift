import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var settingsWindow: NSWindow!
    private var eventMonitor: Any?
    private var settingsHostingController: NSHostingController<AppSettingsView>?
    private var globalHotkeyMonitor: Any?
    private var clickOutsideMonitor: Any?
    private var debugMonitor: Any?
    private var welcomeWindow: NSWindow?
    // 保存当前 Finder 选中项，在面板打开时获取
    private var currentFinderSelection: [URL] = []

    // 提供给外部访问保存的 Finder 选择
    func getSavedFinderSelection() -> [URL] {
        return currentFinderSelection
    }

    // 调试方法：打印 Finder 选择（使用 F6 触发）
    func setupDebugHotkey() {
        // 移除之前的监控
        if let m = debugMonitor {
            NSEvent.removeMonitor(m)
        }
        // 单独的监控器检测 F6
        debugMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // F6 = keyCode 97
            if event.keyCode == 97 {
                let result = self.syncGetFinderSelection()
                print("[DEBUG] ===== Finder Selection (F6) =====")
                print("[DEBUG] 选中的文件: \(result.map { $0.lastPathComponent })")
                print("[DEBUG] 完整路径: \(result.map { $0.path })")
                print("[DEBUG] ==================================")
                return nil // 消费事件
            }
            return event
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化存储服务
        _ = StorageService.shared

        // 创建菜单栏按钮
        setupStatusItem()

        // 创建浮动面板
        setupPanel()

        // 检查辅助功能权限
        checkAccessibilityPermission()

        // 监听全局快捷键
        setupGlobalHotKey()

        // 调试：监听 Ctrl+Option+Command+D 打印 Finder 选择
        setupDebugHotkey()

        // 监听快捷键设置变化通知
        NotificationCenter.default.addObserver(
            forName: .hotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupGlobalHotKey()
        }

        // 隐藏 Dock 图标（菜单栏应用）
        NSApp.setActivationPolicy(.accessory)

        // 请求 Finder 自动化权限
        requestFinderAccess()

        // 检查是否是首次运行
        checkFirstRun()
    }

    private func checkFirstRun() {
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcomeV1")
        if !hasSeenWelcome {
            showWelcome()
        }
    }

    private func showWelcome() {
        let welcomeView = WelcomeView { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasSeenWelcomeV1")
            // 必须推迟到下一个 RunLoop：SwiftUI 按钮 action 执行期间
            // 直接 close/nil 会释放正在处理事件的 NSHostingController → EXC_BAD_ACCESS
            DispatchQueue.main.async {
                self?.welcomeWindow?.close()
                self?.welcomeWindow = nil
            }
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false // 关键：手动管理内存，防止 close() 时意外释放
        window.contentViewController = NSHostingController(rootView: welcomeView)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        self.welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 检查辅助功能权限（全局快捷键需要）
    private func checkAccessibilityPermission() {
        // 先检查是否已有权限（不弹出系统对话框）
        let trusted = AXIsProcessTrusted()
        print("[AppDelegate] 辅助功能权限检查: AXIsProcessTrusted() = \(trusted)")
        print("[AppDelegate] 进程路径: \(Bundle.main.bundlePath)")

        if trusted {
            print("[AppDelegate] 辅助功能权限已授予")
            return
        }

        print("[AppDelegate] 辅助功能权限未授予，全局快捷键可能无法工作")
        // 提示用户手动去设置
        DispatchQueue.main.async {
            self.showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "全局快捷键需要辅助功能权限。请在系统设置中启用 QuickHub 的辅助功能权限，然后重启应用。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            // 打开辅助功能设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// 请求 Finder 自动化权限
    private func requestFinderAccess() {
        let script = """
        tell application "Finder"
            return name of it
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            // 尝试执行脚本，这会触发权限请求
            let result = appleScript.executeAndReturnError(&error)
            if result.stringValue != nil {
                print("[AppDelegate] Finder 权限获取成功")
            } else if let error = error {
                print("[AppDelegate] Finder 权限获取失败: \(error)")
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.circle.fill", accessibilityDescription: "QuickHub")
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        refreshPanelContent()
    }

    private func refreshPanelContent() {
        // 每次刷新都创建新的 PopoverView，确保读取最新配置
        let panelView = PopoverView(onClose: { [weak self] in
            self?.closePanel()
        })

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 450),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.contentViewController = NSHostingController(rootView: panelView)
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden

        // 保存位置（仅当已存在面板时）
        if panel != nil {
            let oldFrame = panel.frame
            panel = newPanel
            panel.setFrame(oldFrame, display: true)
        } else {
            panel = newPanel
        }
    }

    private func setupGlobalHotKey() {
        // 先移除之前的监听
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }

        // 读取保存的快捷键配置
        let savedHotkey = StorageService.shared.loadConfig().settings.hotkey
        let config = savedHotkey ?? HotkeyConfiguration.defaultHotkey

        guard !config.isEmpty else {
            print("[Hotkey] 快捷键为空，跳过注册")
            GlobalHotkeyManager.shared.unregister()
            return
        }

        let hotkeyString = HotkeyUtil.encode(config)
        print("[Hotkey] 注册快捷键: \(hotkeyString) (keyCode=\(config.keyCode), modifiers=\(config.modifiers))")

        // 全局监听键盘事件（使用 Carbon 吞噬按键事件，防止前台程序受键盘输入影响）
        GlobalHotkeyManager.shared.register(keyCode: config.keyCode, modifiers: config.modifiers) { [weak self] in
            // 重要：没权限时如果强行调用获取 Finder 脚本，在某些 macOS 版本上会因为 Sandbox 或内核限制导致 EXC_BAD_ACCESS
            if !AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self?.showAccessibilityAlert()
                }
                return
            }

            // 同步获取 Finder 选择
            let selection = self?.syncGetFinderSelection() ?? []
            
            DispatchQueue.main.async {
                self?.currentFinderSelection = selection
                self?.togglePanel()
            }
        }
    }

    /// 同步获取 Finder 选择（阻塞直到完成）
    private func syncGetFinderSelection() -> [URL] {
        let script = """
        tell application "Finder"
            try
                set sel to selection
                if sel is not {} then
                    set pathList to ""
                    repeat with i from 1 to (count sel)
                        set anItem to item i of sel
                        set pathList to pathList & POSIX path of (anItem as alias) & linefeed
                    end repeat
                    return pathList
                else
                    return POSIX path of (target of front Finder window as alias)
                end if
            on error
                return ""
            end try
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let pathString = result.stringValue {
                let paths = pathString.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { URL(fileURLWithPath: $0) }
                return paths
            }
        }
        return []
    }

    /// 在快捷键触发时立即获取 Finder 选择（异步，已废弃）
    private func prefetchFinderSelection() {
        // 旧方法，已被 syncGetFinderSelection 替代
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            // 打开面板前先打印 Finder 选择
            let selection = syncGetFinderSelection()
            print("[DEBUG] 打开面板前 Finder 选择: \(selection.map { $0.lastPathComponent })")

            // 保存当前 Finder 选择
            currentFinderSelection = selection
            print("[AppDelegate] 保存的 Finder 选择: \(currentFinderSelection.map { $0.lastPathComponent })")

            showPanel()
        }
    }

    private func showPanel() {
        // 刷新面板内容以获取最新配置
        refreshPanelContent()

        // 获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation

        // 获取屏幕尺寸
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // 面板左上角对齐鼠标位置
        // NSPoint.origin 是面板左下角，macOS 坐标系原点在左下角，Y轴向上
        // 要让面板左上角对齐鼠标，panelOrigin.y = mouseLocation.y - panelHeight
        var panelOrigin = NSPoint(
            x: mouseLocation.x,
            y: mouseLocation.y - panel.frame.height
        )

        // 确保面板在屏幕内（右侧边界）
        if panelOrigin.x + panel.frame.width > screenFrame.maxX {
            panelOrigin.x = screenFrame.maxX - panel.frame.width
        }

        // 确保面板在屏幕内（左侧边界）
        if panelOrigin.x < screenFrame.minX {
            panelOrigin.x = screenFrame.minX
        }

        // 确保面板在屏幕内（底部边界）
        if panelOrigin.y < screenFrame.minY {
            panelOrigin.y = screenFrame.minY
        }

        // 确保面板在屏幕内（顶部边界）
        if panelOrigin.y + panel.frame.height > screenFrame.maxY {
            panelOrigin.y = screenFrame.maxY - panel.frame.height
        }

        panel.setFrameOrigin(panelOrigin)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // 开始监听点击事件，用于点击外部关闭
        startClickOutsideMonitor()
    }

    private func closePanel() {
        panel.orderOut(nil)
        stopClickOutsideMonitor()
    }

    // MARK: - 点击外部关闭

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            // 获取鼠标位置
            let mouseLocation = NSEvent.mouseLocation

            // 检查点击位置是否在面板范围内
            let panelFrame = self.panel.frame
            if !NSPointInRect(mouseLocation, panelFrame) {
                // 点击在面板外部，关闭面板
                DispatchQueue.main.async {
                    self.closePanel()
                }
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    func openSettings() {
        closePanel()

        // 每次打开设置都创建新的窗口，避免复用问题
        let settingsView = AppSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.title = "QuickHub 设置"
        settingsWindow.contentViewController = hostingController
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
