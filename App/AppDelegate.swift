import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var settingsWindow: NSWindow!
    private var eventMonitor: Any?
    private var settingsHostingController: NSHostingController<AppSettingsView>?
    private var globalHotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化存储服务
        _ = StorageService.shared

        // 创建菜单栏按钮
        setupStatusItem()

        // 创建浮动面板
        setupPanel()

        // 监听全局快捷键
        setupGlobalHotKey()

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
            button.image = NSImage(systemSymbolName: "command.circle.fill", accessibilityDescription: "RightClickX")
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

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 450),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = NSHostingController(rootView: panelView)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
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
            return
        }

        print("[Hotkey] 注册快捷键: keyCode=\(config.keyCode), modifiers=\(config.modifiers)")

        // 全局监听键盘事件
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventModifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            let configModifiers = config.modifiers & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

            print("[Hotkey] 收到事件: keyCode=\(event.keyCode), modifiers=\(eventModifiers), 期望: keyCode=\(config.keyCode), modifiers=\(configModifiers)")

            if event.keyCode == config.keyCode && eventModifiers == configModifiers {
                print("[Hotkey] 快捷键匹配! 切换面板")
                DispatchQueue.main.async {
                    self?.togglePanel()
                }
            }
        }
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        // 刷新面板内容以获取最新配置
        refreshPanelContent()

        // 获取鼠标位置，在鼠标位置显示面板
        let mouseLocation = NSEvent.mouseLocation

        // 获取屏幕尺寸
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // 计算面板位置（显示在鼠标附近）
        var panelOrigin = mouseLocation
        panelOrigin.x -= panel.frame.width / 2  // 居中于鼠标

        // 确保面板在屏幕内
        if panelOrigin.x < screenFrame.minX {
            panelOrigin.x = screenFrame.minX
        } else if panelOrigin.x + panel.frame.width > screenFrame.maxX {
            panelOrigin.x = screenFrame.maxX - panel.frame.width
        }

        // 面板显示在鼠标上方
        panelOrigin.y = mouseLocation.y - panel.frame.height - 10

        // 如果下方空间不够，显示在鼠标下方
        if panelOrigin.y < screenFrame.minY {
            panelOrigin.y = mouseLocation.y + 20
        }

        panel.setFrameOrigin(panelOrigin)
        panel.makeKeyAndOrderFront(nil)

        // 确保窗口可见
        panel.orderFrontRegardless()
    }

    private func closePanel() {
        panel.orderOut(nil)
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

        settingsWindow.title = "RightClickX 设置"
        settingsWindow.contentViewController = hostingController
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
