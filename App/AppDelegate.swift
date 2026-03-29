import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var settingsWindow: NSWindow!
    private var eventMonitor: Any?
    private var settingsHostingController: NSHostingController<AppSettingsView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化存储服务
        _ = StorageService.shared

        // 创建菜单栏按钮
        setupStatusItem()

        // 创建浮动面板
        setupPanel()

        // 监听全局快捷键
        setupGlobalHotKey()

        // 隐藏 Dock 图标（菜单栏应用）
        NSApp.setActivationPolicy(.accessory)
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
        // Cmd+Shift+P 打开面板
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "p" {
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
