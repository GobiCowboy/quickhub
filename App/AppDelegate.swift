import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var clickOutsideMonitor: Any?
    
    // 保存当前 Finder 选中项
    private var currentFinderSelection: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] ⚡️ QuickHub 正在启动核心服务...")
        
        // 1. 初始化配置与菜单
        _ = StorageService.shared
        setupStatusItem()
        setupPanel()
        
        // 2. 注册快捷键
        setupGlobalHotkey()
        
        print("[AppDelegate] ✅ 启动完毕")
    }

    // 提供给外部访问保存的 Finder 选择
    func getSavedFinderSelection() -> [URL] {
        return currentFinderSelection
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
        let popoverView = PopoverView(onClose: { [weak self] in
            self?.closePanel()
        })
        
        let hostingController = NSHostingController(rootView: popoverView)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 350),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.contentViewController = hostingController
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
    }

    private func setupGlobalHotkey() {
        let config = StorageService.shared.loadConfig().settings.hotkey ?? HotkeyConfiguration.defaultHotkey
        
        GlobalHotkeyManager.shared.register(keyCode: config.keyCode, modifiers: config.modifiers) { [weak self] in
            // 权限检查
            if !AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self?.showAccessibilityAlert()
                }
                return
            }

            // 获取 Finder 选择
            let selection = self?.syncGetFinderSelection() ?? []
            
            DispatchQueue.main.async {
                self?.currentFinderSelection = selection
                self?.togglePanel()
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
        ConfigObserver.shared.refresh()
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        var panelOrigin = NSPoint(
            x: mouseLocation.x - 120, // 居中于鼠标
            y: mouseLocation.y - panel.frame.height
        )
        // 边界限制逻辑... (此处略微精简，确保在屏幕内)
        panel.setFrameOrigin(panelOrigin)
        panel.makeKeyAndOrderFront(nil)
        startClickOutsideMonitor()
    }

    func closePanel() {
        panel.orderOut(nil)
        stopClickOutsideMonitor()
    }

    func openSettings() {
        closePanel()
        // 发送给 SwiftUI 管理的 Settings
        if let url = URL(string: "quickhub://settings") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "QuickHub 需要辅助功能权限来拦截全局快捷键。请在系统设置中授权。"
        alert.addButton(withTitle: "前往设置")
        alert.addButton(withTitle: "稍后")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    private func syncGetFinderSelection() -> [URL] {
        let finderApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.apple.finder" }
        guard let finder = finderApps.first else { return [] }
        let finderElement = AXUIElementCreateApplication(finder.processIdentifier)
        var selectionValue: AnyObject?
        if AXUIElementCopyAttributeValue(finderElement, "AXSelectedChildren" as CFString, &selectionValue) == .success,
           let selection = selectionValue as? [AXUIElement] {
            var urls: [URL] = []
            for element in selection {
                var urlValue: AnyObject?
                if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlValue) == .success,
                   let url = urlValue as? URL { urls.append(url) }
            }
            if !urls.isEmpty { return urls }
        }
        return []
    }

    private func startClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
