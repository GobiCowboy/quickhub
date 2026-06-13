import AppKit
import ApplicationServices
import OSLog
import SwiftUI

fileprivate func rightClickEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap = appDelegate.rightClickEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .rightMouseDown else {
        return Unmanaged.passUnretained(event)
    }

    // Option + 右键：透传给系统，显示原生右键菜单
    if event.flags.contains(.maskAlternate) {
        return Unmanaged.passUnretained(event)
    }

    guard appDelegate.shouldInterceptRightClick(at: event.location) else {
        return Unmanaged.passUnretained(event)
    }

    // 用 Accessibility API 判断是否点击在桌面表面
    let clickedOnDesktop = appDelegate.isClickOnDesktopSurface(at: event.location)

    DispatchQueue.main.async {
        appDelegate.handleInterceptedRightClick(clickedOnDesktop: clickedOnDesktop)
    }

    return nil
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.rightclickx.app", category: "RightClick")

    private enum PanelInvocationSource {
        case menuBar
        case hotkey
        case rightClick

        var showsFooterActions: Bool {
            switch self {
            case .menuBar:
                return true
            case .hotkey, .rightClick:
                return false
            }
        }
    }

    static var shared: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    private var settingsHostingController: NSHostingController<AppSettingsView>?
    private var globalHotkeyMonitor: Any?
    private var panelDismissMonitor: Any?
    private var debugMonitor: Any?
    private var languageObserver: NSObjectProtocol?
    fileprivate var rightClickEventTap: CFMachPort?
    private var rightClickRunLoopSource: CFRunLoopSource?
    private var welcomeWindow: NSWindow?
    private var accessibilityAlertShown = false
    // 保存当前 Finder 选中项，在面板打开时获取
    private var currentFinderSelection: [URL] = []
    private(set) var finderWasActive = false

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

        // 提供标准编辑菜单，保证文本框里 ⌘V / ⌘C / ⌘A 等快捷键可用。
        setupEditMenu()

        // 创建菜单栏按钮
        setupStatusItem()

        // 创建浮动面板
        setupPanel()

        // 检查辅助功能权限
        checkAccessibilityPermission()

        // 监听全局快捷键
        setupGlobalHotKey()

        // 监听全局右键，用 QuickHub 面板替代系统右键菜单
        setupRightClickInterceptor()

        // 调试：监听 Ctrl+Option+Command+D 打印 Finder 选择
        setupDebugHotkey()

        // 监听快捷键设置变化通知
        NotificationCenter.default.addObserver(
            forName: .hotkeySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupGlobalHotKey()
            self?.setupRightClickInterceptor()
        }

        // 隐藏 Dock 图标（菜单栏应用）
        NSApp.setActivationPolicy(.accessory)

        // 检查是否是首次运行
        checkFirstRun()
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: LocaleManager.shared.localized("app.settings.title"),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit QuickHub",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
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
            self?.welcomeWindow?.close()
            self?.welcomeWindow = nil
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
        window.contentViewController = NSHostingController(rootView: welcomeView)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)

        self.welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 检查辅助功能权限（全局快捷键需要）
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        print("[AppDelegate] 辅助功能权限检查: AXIsProcessTrusted() = \(trusted)")
        print("[AppDelegate] 进程路径: \(Bundle.main.bundlePath)")

        if trusted {
            print("[AppDelegate] 辅助功能权限已授予")
            return
        }

        print("[AppDelegate] 辅助功能权限未授予，全局快捷键可能无法工作")
        DispatchQueue.main.async { [weak self] in
            self?.showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        guard !accessibilityAlertShown else { return }
        accessibilityAlertShown = true

        let alert = NSAlert()
        alert.messageText = localized("app.accessibility.title")
        alert.informativeText = localized("app.accessibility.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("app.accessibility.open_settings"))
        alert.addButton(withTitle: localized("app.accessibility.later"))

        if alert.runModal() == .alertFirstButtonReturn {
            // 打开辅助功能设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        accessibilityAlertShown = false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "command.circle.fill", accessibilityDescription: "QuickHub")
            }

            let menu = NSMenu()
            menu.autoenablesItems = false
            let settingsItem = menu.addItem(
                withTitle: LocaleManager.shared.localized("app.settings.title"),
                action: #selector(openSettingsFromMenu),
                keyEquivalent: ""
            )
            settingsItem.target = self
            menu.addItem(.separator())
            let quitItem = menu.addItem(
                withTitle: localized("common.quit"),
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: ""
            )
            quitItem.target = NSApp

            statusItem.menu = menu
        }
    }

    private func setupPanel() {
        refreshPanelContent(showFooterActions: true, height: 392)
    }

    private func refreshPanelContent(showFooterActions: Bool, height: CGFloat) {
        // 每次刷新都创建新的 PopoverView，确保读取最新配置
        let panelView = PopoverView(
            panelWidth: 280,
            panelHeight: height,
            showsFooterActions: showFooterActions,
            onClose: { [weak self] in
                self?.closePanel()
            }
        )

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: height),
            styleMask: [.borderless],
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
        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true
        newPanel.setContentSize(NSSize(width: 280, height: height))

        if panel != nil {
            let oldFrame = panel.frame
            panel.orderOut(nil)
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
                self?.togglePanelFromHotkey()
            }
        }
    }

    private func setupRightClickInterceptor() {
        stopRightClickInterceptor()

        let enabled = StorageService.shared.loadConfig().settings.interceptRightClick
        guard enabled else {
            print("[RightClick] 右键拦截已关闭")
            logger.info("Right click interception disabled")
            return
        }

        guard AXIsProcessTrusted() else {
            print("[RightClick] 辅助功能权限未授予，无法拦截右键")
            logger.error("Accessibility permission missing; cannot install right click event tap")
            return
        }

        let eventMask =
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: rightClickEventTapCallback,
            userInfo: userInfo
        ) else {
            print("[RightClick] 创建右键事件 Tap 失败，请检查辅助功能/输入监控权限")
            logger.error("Failed to create right click event tap")
            return
        }

        rightClickEventTap = eventTap
        rightClickRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        if let source = rightClickRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("[RightClick] 右键拦截已启用")
            logger.info("Right click interception enabled")
        }
    }

    fileprivate func shouldInterceptRightClick(at point: CGPoint) -> Bool {
        return isPointOnFinderManagedSurface(at: point)
    }

    private func isPointOnFinderManagedSurface(at point: CGPoint) -> Bool {
        guard NSScreen.screens.contains(where: { $0.visibleFrame.contains(point) }) else {
            logger.debug("Right click point \(point.debugDescription, privacy: .public) is outside visible screen frame")
            return false
        }

        if let accessibilityHit = accessibilityHitUnderCursor(at: point) {
            if accessibilityHit.shouldIntercept {
                logger.debug(
                    "Right click accessibility hit owner=\(accessibilityHit.owner, privacy: .public) role=\(accessibilityHit.role, privacy: .public) subrole=\(accessibilityHit.subrole, privacy: .public) title=\(accessibilityHit.title, privacy: .public) description=\(accessibilityHit.description, privacy: .public) point=\(point.debugDescription, privacy: .public) handle=true"
                )
                return true
            }

            logger.debug(
                "Right click accessibility hit owner=\(accessibilityHit.owner, privacy: .public) role=\(accessibilityHit.role, privacy: .public) subrole=\(accessibilityHit.subrole, privacy: .public) title=\(accessibilityHit.title, privacy: .public) description=\(accessibilityHit.description, privacy: .public) point=\(point.debugDescription, privacy: .public) handle=false"
            )
        } else {
            logger.debug("Right click accessibility hit not available for point \(point.debugDescription, privacy: .public)")
        }

        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            logger.debug("Right click point \(point.debugDescription, privacy: .public) could not query window list")
            return false
        }

        for window in windowList {
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            if bounds.contains(point) {
                let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
                let windowName = window[kCGWindowName as String] as? String ?? ""
                let layer = window[kCGWindowLayer as String] as? Int ?? -1

                let shouldHandleDesktop =
                    ownerName == "Finder" ||
                    (ownerName == "Dock" && windowName.localizedCaseInsensitiveContains("Desktop")) ||
                    (ownerName == "Window Server" && windowName.localizedCaseInsensitiveContains("Desktop"))

                logger.debug(
                    "Right click hit window owner=\(ownerName, privacy: .public) name=\(windowName, privacy: .public) layer=\(layer, privacy: .public) point=\(point.debugDescription, privacy: .public) handle=\(shouldHandleDesktop, privacy: .public)"
                )
                return shouldHandleDesktop
            }
        }

        logger.debug("Right click point \(point.debugDescription, privacy: .public) did not hit any on-screen window")
        return false
    }

    private struct AccessibilityHit {
        let owner: String
        let role: String
        let subrole: String
        let title: String
        let description: String
        let shouldIntercept: Bool
    }

    private func accessibilityHitUnderCursor(at point: CGPoint) -> AccessibilityHit? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        guard status == .success, let element else {
            return nil
        }

        let owner = accessibilityOwner(for: element)
        let role = accessibilityStringValue(for: kAXRoleAttribute as CFString, element: element) ?? ""
        let subrole = accessibilityStringValue(for: kAXSubroleAttribute as CFString, element: element) ?? ""
        let title = accessibilityStringValue(for: kAXTitleAttribute as CFString, element: element) ?? ""
        let description = accessibilityStringValue(for: kAXDescriptionAttribute as CFString, element: element) ?? ""

        let normalizedOwner = owner.lowercased()
        let normalizedRole = role.lowercased()
        let normalizedSubrole = subrole.lowercased()
        let normalizedTitle = title.lowercased()
        let normalizedDescription = description.lowercased()

        let isDesktopSurface =
            normalizedRole.contains("desktop") ||
            normalizedSubrole.contains("desktop") ||
            normalizedTitle.contains("desktop") ||
            normalizedDescription.contains("desktop")

        let shouldIntercept =
            normalizedOwner.contains("finder") ||
            isDesktopSurface

        return AccessibilityHit(
            owner: owner,
            role: role,
            subrole: subrole,
            title: title,
            description: description,
            shouldIntercept: shouldIntercept
        )
    }

    private func accessibilityOwner(for element: AXUIElement) -> String {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return ""
        }

        let bundleIdentifier = app.bundleIdentifier ?? ""
        if !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        return app.localizedName ?? ""
    }

    private func accessibilityStringValue(for attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else {
            return nil
        }

        return value as? String
    }

    private func stopRightClickInterceptor() {
        if let eventTap = rightClickEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let source = rightClickRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            rightClickRunLoopSource = nil
        }

        rightClickEventTap = nil
    }

    fileprivate func handleInterceptedRightClick(clickedOnDesktop: Bool) {
        let finderIsFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        finderWasActive = !clickedOnDesktop && finderIsFront
        let selection = syncGetFinderSelection()
        currentFinderSelection = selection

        logger.info("Right click intercepted; opening panel")
        closePanel()
        showPanel(source: .rightClick)
    }

    /// 判断点击是否在桌面表面
    fileprivate func isClickOnDesktopSurface(at point: CGPoint) -> Bool {
        guard let hit = accessibilityHitUnderCursor(at: point) else { return true }
        let isDesktop =
            hit.subrole.lowercased().contains("desktop") ||
            hit.role.lowercased().contains("desktop") ||
            hit.title.lowercased().contains("desktop") ||
            hit.description.lowercased().contains("desktop")
        if isDesktop { return true }
        // owner 不是 Finder → 可能是桌面
        return !hit.owner.lowercased().contains("finder")
    }

    /// 同步获取 Finder 选择（阻塞直到完成）
    private func syncGetFinderSelection() -> [URL] {
        return FinderService.shared.getSelectedItems()
    }

    /// 在快捷键触发时立即获取 Finder 选择（异步，已废弃）
    private func prefetchFinderSelection() {
        // 旧方法，已被 syncGetFinderSelection 替代
    }

    @objc private func togglePanelFromMenuBar() {
        togglePanel(source: .menuBar)
    }

    @objc private func togglePanelFromHotkey() {
        togglePanel(source: .hotkey)
    }

    private func togglePanel(source: PanelInvocationSource) {
        if panel.isVisible {
            closePanel()
        } else {
            // 记录打开面板时 Finder 是否为前台（必须在 AppleScript 之前检查）
            finderWasActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"

            // 打开面板前先打印 Finder 选择
            let selection = syncGetFinderSelection()

            // 保存当前 Finder 选择
            currentFinderSelection = selection
            print("[AppDelegate] 保存的 Finder 选择: \(currentFinderSelection.map { $0.lastPathComponent })")

            showPanel(source: source)
        }
    }

    private func showPanel(source: PanelInvocationSource) {
        // 刷新面板内容以获取最新配置
        let height = preferredPanelHeight(showFooterActions: source.showsFooterActions)
        refreshPanelContent(showFooterActions: source.showsFooterActions, height: height)

        // 获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation

        // 获取屏幕尺寸
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // 面板左上角对齐鼠标位置
        // NSPoint.origin 是面板左下角，macOS 坐标系原点在左下角，Y轴向上
        // 要让面板左上角对齐鼠标，panelOrigin.y = mouseLocation.y - panelHeight
        let verticalLift: CGFloat = 30
        var panelOrigin = NSPoint(
            x: mouseLocation.x,
            y: mouseLocation.y - panel.frame.height + verticalLift
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

        startPanelDismissMonitor()
    }

    private func preferredPanelHeight(showFooterActions: Bool) -> CGFloat {
        let config = StorageService.shared.loadConfig()
        let enabledGroups = config.groups.filter { group in
            group.enabled && group.items.contains(where: { $0.enabled })
        }

        let topChrome: CGFloat = 41
        let divider: CGFloat = 1
        let footer: CGFloat = showFooterActions ? 31 : 0
        let outerPadding: CGFloat = 10
        let groupTitleHeight: CGFloat = 16
        let rowHeight: CGFloat = 28
        let groupDivider: CGFloat = 8

        var contentHeight: CGFloat = topChrome + divider + footer + outerPadding
        for (index, group) in enabledGroups.enumerated() {
            if !group.name.isEmpty {
                contentHeight += groupTitleHeight
            }

            let enabledItems = group.items.filter { $0.enabled }.count
            contentHeight += CGFloat(enabledItems) * rowHeight

            if index != enabledGroups.count - 1 {
                contentHeight += groupDivider
            }
        }

        let minHeight: CGFloat = showFooterActions ? 392 : 360
        let maxHeight: CGFloat = showFooterActions ? 560 : 520
        return min(max(contentHeight, minHeight), maxHeight)
    }

    private func closePanel() {
        panel.orderOut(nil)
        stopPanelDismissMonitor()
    }

    // MARK: - 面板关闭

    private func startPanelDismissMonitor() {
        stopPanelDismissMonitor()

        panelDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            if event.type == .keyDown {
                DispatchQueue.main.async {
                    self.closePanel()
                }
                return
            }

            let mouseLocation = NSEvent.mouseLocation
            if !NSPointInRect(mouseLocation, self.panel.frame) {
                DispatchQueue.main.async {
                    self.closePanel()
                }
            }
        }
    }

    private func stopPanelDismissMonitor() {
        if let monitor = panelDismissMonitor {
            NSEvent.removeMonitor(monitor)
            panelDismissMonitor = nil
        }
    }

    func openSettings() {
        CommandExecutor.shared.dismissFileInfoPanel()
        closePanel()

        var needsDeferredCentering = false
        if settingsWindow == nil {
            let settingsView = AppSettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            settingsHostingController = hostingController

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1120, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.isReleasedWhenClosed = false
            window.title = LocaleManager.shared.localized("app.settings.title")
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.contentViewController = hostingController
            settingsWindow = window
            needsDeferredCentering = true

            if languageObserver == nil {
                languageObserver = NotificationCenter.default.addObserver(
                    forName: .languageChanged,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.settingsWindow?.title = LocaleManager.shared.localized("app.settings.title")
                    }
                }
            }
        } else {
            settingsHostingController?.rootView = AppSettingsView()
        }

        guard let settingsWindow else { return }
        settingsWindow.title = LocaleManager.shared.localized("app.settings.title")
        settingsWindow.backgroundColor = .windowBackgroundColor
        settingsWindow.isOpaque = true
        centerSettingsWindow(settingsWindow)
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if needsDeferredCentering {
            DispatchQueue.main.async { [weak self] in
                guard let settingsWindow = self?.settingsWindow else { return }
                self?.centerSettingsWindow(settingsWindow)
            }
        }
    }

    private func centerSettingsWindow(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        let x = visibleFrame.midX - frame.width / 2
        let y = visibleFrame.midY - frame.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
