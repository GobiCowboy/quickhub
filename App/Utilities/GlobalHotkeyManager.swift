import AppKit
import Carbon

fileprivate func globalHotkeyHandlerCallback(nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    if GetEventClass(theEvent) == kEventClassKeyboard && GetEventKind(theEvent) == UInt32(kEventHotKeyPressed) {
        manager.action?()
    }
    return noErr
}

/// 负责从系统底层（Carbon）注册全局快捷键并安全拦截击键信号，防止快捷键泄漏给 Finder 造成选中项偏移。
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var isHandlerInstalled = false
    var action: (() -> Void)?
    
    private init() {}
    
    func register(keyCode: UInt16, modifiers: UInt, action: @escaping () -> Void) {
        self.action = action
        
        // 注销已有的快捷键
        unregister()
        
        // 安装全局事件处理器（仅安装一次）
        if !isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let ptr = Unmanaged.passUnretained(self).toOpaque()
            
            InstallEventHandler(GetApplicationEventTarget(), globalHotkeyHandlerCallback, 1, &eventType, ptr, nil)
            isHandlerInstalled = true
        }
        
        // HotKey 签名：'RCKX' 转 OSType
        let hotKeyID = EventHotKeyID(signature: OSType(0x52434B58), id: 1)
        
        // 转换 NSEvent Modifier 为 Carbon Modifier
        var carbonModifiers: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let status = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("[GlobalHotkeyManager] 注册全局快捷键失败, Carbon OSStatus: \(status)")
        } else {
            print("[GlobalHotkeyManager] 注册全局快捷键成功 (Carbon底层拦截)")
        }
    }
    
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            print("[GlobalHotkeyManager] 已注销全局快捷键")
        }
    }
}
