import AppKit
import Carbon

// MARK: - 快捷键工具类
enum HotkeyUtil {

    // MARK: - 修饰符符号映射
    private static let modifierSymbols: [(flags: NSEvent.ModifierFlags, symbol: String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘")
    ]

    // MARK: - 键码到字符映射
    private static let keyCodeToString: [UInt16: String] = [
        // 字母键
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        // 数字行
        53: "Esc",
        // 功能键
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 101: "F8", 109: "F9", 103: "F10", 111: "F11", 105: "F12",
        // 方向键
        123: "←", 124: "→", 125: "↓", 126: "↑",
        // 控制键
        36: "↩", 51: "⌫", 117: "⌦", 115: "↖", 119: "↘",
        116: "↕", 121: "⎙", 130: "ins",
        // 小键盘
        67: "*", 69: "+", 76: "↩", 78: "-", 65: "."
    ]

    // MARK: - 编码为人类可读格式
    static func encode(keyCode: UInt16, modifiers: UInt) -> String {
        guard keyCode != 0 else { return "未设置" }

        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result = ""

        // 按固定顺序添加修饰符符号
        for (flag, symbol) in modifierSymbols {
            if flags.contains(flag) {
                result += symbol
            }
        }

        // 添加按键字符
        if let keyString = keyCodeToString[keyCode] {
            result += keyString
        } else {
            result += "Key(\(keyCode))"
        }

        return result
    }

    // MARK: - 从人类可读格式解码
    static func decode(_ string: String) -> (keyCode: UInt16, modifiers: UInt)? {
        guard string != "未设置" && !string.isEmpty else {
            return (0, 0)
        }

        var modifiers: UInt = 0
        var keyPart = string

        // 解析修饰符符号
        for (flag, symbol) in modifierSymbols {
            if keyPart.hasPrefix(symbol) {
                modifiers |= flag.rawValue
                keyPart = String(keyPart.dropFirst(symbol.count))
            }
        }

        // 查找键码
        var keyCode: UInt16 = 0
        for (code, str) in keyCodeToString {
            if keyPart == str {
                keyCode = code
                break
            }
        }

        if keyCode == 0 && !keyPart.isEmpty {
            // 尝试解析 Key(x) 格式
            if keyPart.hasPrefix("Key(") && keyPart.hasSuffix(")") {
                let numStr = keyPart.dropFirst(4).dropLast()
                keyCode = UInt16(numStr) ?? 0
            }
        }

        return (keyCode, modifiers)
    }

    // MARK: - 从 NSEvent 提取快捷键配置
    static func extractFromEvent(_ event: NSEvent) -> HotkeyConfiguration {
        let modifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        return HotkeyConfiguration(keyCode: event.keyCode, modifiers: modifiers)
    }

    // MARK: - 检测系统快捷键冲突
    static func checkSystemConflicts(keyCode: UInt16, modifiers: UInt) -> [String] {
        var conflicts: [String] = []

        let flags = NSEvent.ModifierFlags(rawValue: modifiers)

        // 检测常见系统快捷键冲突
        let systemHotkeys: [(flags: NSEvent.ModifierFlags, keyCode: UInt16, name: String)] = [
            (.command, 49, "⌘+Space - Spotlight（可能被替换）"),
            (.command, 36, "⌘+↩ - 固定到程序坞"),
            (.command, 53, "⌘+Esc - 强制退出"),
            (.control, 36, "⌃+↩ - 切换用户"),
            (.command, 96, "⌘+F1 - 切换显示器"),
            (.command, 97, "⌘+F2 - 系统设置"),
            (.command, 98, "⌘+F3 - 应用 Exposé"),
            (.command, 99, "⌘+F4 - 显示器 Exposé"),
            (.command, 100, "⌘+F5 - 调度中心"),
            (.control, 101, "⌃+F6 - 语音控制"),
            (.option, 49, "⌥+Space - Apple 菜单"),
        ]

        for hotkey in systemHotkeys {
            // 检查修饰符是否匹配（不区分顺序）
            let requiredFlags = hotkey.flags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            let currentFlags = modifiers & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

            if requiredFlags == currentFlags && hotkey.keyCode == keyCode {
                conflicts.append(hotkey.name)
            }
        }

        // 检查是否缺少修饰符（纯功能键或单键）
        if modifiers == 0 {
            conflicts.append("无修饰符快捷键可能与系统冲突")
        } else if !flags.contains(.command) && !flags.contains(.control) {
            conflicts.append("建议使用 ⌘ 或 ⌃ 修饰符以避免冲突")
        }

        return conflicts
    }

    // MARK: - 编码快捷键配置
    static func encode(_ config: HotkeyConfiguration) -> String {
        return encode(keyCode: config.keyCode, modifiers: config.modifiers)
    }

    // MARK: - 解码为快捷键配置
    static func decodeConfig(_ string: String) -> HotkeyConfiguration {
        guard let result = decode(string) else {
            return .empty
        }
        return HotkeyConfiguration(keyCode: result.keyCode, modifiers: result.modifiers)
    }
}
